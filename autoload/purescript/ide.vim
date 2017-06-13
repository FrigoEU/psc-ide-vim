let s:started = v:false
let s:external = v:false
let s:valid = v:false

fun! purescript#ide#started()
  return s:started
endfun

fun! purescript#ide#setStarted(val)
  let s:started = a:val
endfun

fun! purescript#ide#external()
  return s:external
endfun

fun! purescript#ide#setExternal(val)
  let s:external = a:val
endfun

fun! purescript#ide#valid()
  return s:valid
endfun

fun! purescript#ide#setValid(val)
  let s:valid = a:val
endfun

fun! purescript#ide#call(input, errorm, isRetry, cb)
  call purescript#ide#utils#debug("purescript#ide#call: command: " . json_encode(a:input), 3)

  if !s:valid
    call PSCIDEprojectValidate()
  endif

  if !s:started
    call purescript#ide#utils#debug("purescript#ide#call: no server found", 1)

    let expectedCWD = fnamemodify(purescript#ide#utils#findRoot(), ":p:h")
    let cwdcommand = {'command': 'cwd'}

    let jobid = async#job#start(
	  \ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	  \ { "on_stdout": {ch, msg -> s:startFn(a:input, a:errorm, a:cb, cwdcommand, msg)}
	  \ , "on_stderr": {ch, err -> purescript#ide#utils#debug("s:callPscIde error: " . string(err), 3)}
	  \ })
    call async#job#send(jobid, json_encode(cwdcommand) . "\n")
    return
  endif

  let enc = json_encode(a:input)
  let jobid = async#job#start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "on_stdout": {ch, msg -> a:cb(s:callFn(a:input, a:errorm, a:isRetry, a:cb, msg))}
	\ , "on_stderr": {ch, err -> purescript#ide#utils#debug("s:callPscIde error: " . string(err), 0)}
	\ })
  call async#job#send(jobid, enc . "\n")
  " call async#job#stop(jobid) " Not needed I think, \n stops job
endfun

fun! purescript#ide#callSync(input, errorm, isRetry)
  call purescript#ide#utils#debug("purescript#ide#callSync: command: " . json_encode(a:input), 3)

  if !s:valid
    call PSCIDEprojectValidate()
  endif

  if !s:started
    let expectedCWD = fnamemodify(purescript#ide#utils#findRoot(), ":p:h")
    let cwdcommand = {'command': 'cwd'}

    call purescript#ide#utils#debug("purescript#ide#callSync: no server found", 1)
    let cwdresp = purescript#ide#utils#system("purs ide client -p " . g:psc_ide_server_port, json_encode(cwdcommand))
    return s:startFn(a:input, a:errorm, 0, cwdcommand, cwdresp)
  else
    call purescript#ide#utils#debug("purescript#ide#callSync: trying to reach server again", 1)
    let enc = json_encode(a:input)
    let resp = purescript#ide#utils#system("purs ide client -p " . g:psc_ide_server_port, enc)
    return s:callFn(a:input, a:errorm, a:isRetry, 0, resp)
  endif
endfun

fun! s:startFn(input, errorm, cb, cwdcommand, cwdresp)
  let cwd = fnamemodify(purescript#ide#utils#findRoot(), ":p:h")
  try
    let cwdrespDecoded = json_decode(a:cwdresp)
  catch /.*/
    let cwdrespDecoded = {"resultType": "failed", "error": a:cwdresp}
  endtry

  call purescript#ide#utils#debug("s:startFn: resp: " . json_encode(cwdrespDecoded), 1)

  if type(cwdrespDecoded) == v:t_dict && cwdrespDecoded.resultType ==# 'success'
    if cwd != cwdrespDecoded.result
      call purescript#ide#utils#debug("s:startFn: found server, re-starting", 1)
      call PSCIDEend()
      call PSCIDEstart(1)
    else
      call purescript#ide#utils#log("started", v:true)
      let s:started = v:true
      let s:external = v:true
    endif
  else
    call purescript#ide#utils#debug("s:startFn: starting new server", 1)
    call PSCIDEstart(1)
  endif
  call purescript#ide#utils#debug("s:startFn: resending", 1)
  if (type(a:cb) == type(0) && !a:cb)
    let cwdresp = purescript#ide#utils#system(
	  \ "purs ide client -p" . g:psc_ide_server_port,
	  \ json_encode(a:cwdcommand)
	  \ )
    call s:retryFn(a:input, a:errorm, 0, cwd, cwdresp)
  else
    let jobid = async#job#start(
	  \ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	  \ { "on_stdout": { ch, resp -> s:retryFn(a:input, a:errorm, a:cb, expectedCWD, resp) }
	  \ , "on_stderr": { ch, err -> purescript#ide#utils#warn(purescript#ide#utils#toString(err)) }
	  \ })
    call async#job#send(jobid, json_encode(a:cwdcommand) . "\n")
  endif
endfun

fun! s:retryFn(input, errorm, cb, expectedCWD, cwdresp2)
  call purescript#ide#utils#debug("s:retryFn: response: " . json_encode(a:cwdresp2), 1)

  if type(a:cwdresp2) == v:t_list
    let json = a:cwdresp2[0]
  else
    let json = a:cwdresp2
  endif

  try
    let cwdresp2Decoded = json_decode(json)
  catch /.*/
    let cwdresp2Decoded = {"resultType": "failed", "error": a:cwdresp2}
  endtry
  call purescript#ide#utils#debug("s:retryFn: response: " . json_encode(cwdresp2Decoded), 1)

  if type(cwdresp2Decoded) == type({}) && cwdresp2Decoded.resultType ==# 'success' 
     \ && cwdresp2Decoded.result == a:expectedCWD
    call purescript#ide#utils#debug("s:retryFn: success", 1)
    call PSCIDEload(1, "")
  else
    call purescript#ide#utils#debug("s:retryFn: aborting...", 1)
    return
  endif

  let enc = json_encode(a:input)
  if (type(a:cb) == type(0))
    let resp = purescript#ide#utils#system(
	  \ "purs ide client -p" . g:psc_ide_server_port,
	  \ enc
	  \ )
    return s:callFn(a:input, a:errorm, 1, 0, resp)
  endif

  if (type(a:cb) == type(0) && !a:cb)
    let resp = purescript#ide#utils#system(
	  \ "purs ide client -p" . g:psc_ide_server_port
	  \ enc
	  \ )
    return s:callFn(a:input, a:errorm, 1, 0, resp)
  endif
  call purescript#ide#utils#debug("callPscIde: command: " . enc, 3)
  let jobid = async#job#start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "on_stdout": {ch, resp -> a:cb(s:callFn(a:input, a:errorm, 1, a:cb, resp))}
	\ , "on_stderr": {ch, err -> purescript#ide#utils#debug("s:retryFn error: " . err, 3)}
	\ })
  call async#job#send(jobid, enc . "\n")
endfun

fun! s:callFn(input, errorm, isRetry, cb, resp)
  call purescript#ide#utils#debug("s:callFn: response: " . json_encode(a:resp), 3)

  if (type(a:resp) == type([]))
    let json = a:resp[0]
  else
    let json = a:resp
  endif

  try
    let decoded = json_decode(json)
  catch /.*/
    let s:started = v:false
    let s:external = v:false
    let decoded =
	  \ { "resultType": "error"
	  \ , "result": "failed to decode response"
	  \ }

    if a:isRetry
      call purescript#ide#utils#log("failed to contact server", v:true)
    else
      " Seems saving often causes `purs ide server` to crash. Haven't been able
      " to figure out why. It doesn't crash when I run it externally...
      " retrying is then the next best thing
      return s:callPscIde(a:input, a:errorm, 1, a:cb) " Keeping track of retries so we only retry once
    endif
  endtry

  if (type(decoded) != type({}) || decoded['resultType'] !=# 'success') 
      \ && type(a:errorm) == v:t_string
    call purescript#ide#utils#log(a:errorm)
  endif
  return decoded
endfun
