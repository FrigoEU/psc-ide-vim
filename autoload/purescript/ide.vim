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

fun! purescript#ide#call(input, errorm, isRetry, cb, ...)
  let silent = a:0 >= 1 ? a:1 : v:false

  call purescript#ide#utils#debug("purescript#ide#call: command: " . json_encode(a:input), 3)

  if !s:valid
    call PSCIDEprojectValidate(v:true)
  endif

  if !s:started
    call purescript#ide#utils#debug("purescript#ide#call: no server found", 1)

    let expectedCWD = fnamemodify(purescript#ide#utils#findRoot(), ":p:h")
    let cwdcommand = {'command': 'cwd'}

    let jobid = purescript#job#start(
	  \ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	  \ { "on_stdout": {ch, msg -> s:startFn(a:input, a:errorm, a:cb, cwdcommand, msg, silent)}
	  \ , "on_stderr": {ch, err -> purescript#ide#utils#debug("purescript#ide#call error: " . string(err), 3)}
	  \ })
    call purescript#job#send(jobid, json_encode(cwdcommand) . "\n")
    return
  endif

  let enc = json_encode(a:input)
  let jobid = purescript#job#start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "on_stdout": {ch, msg -> a:cb(s:callFn(a:input, a:errorm, a:isRetry, a:cb, msg))}
	\ , "on_stderr": {ch, err -> purescript#ide#utils#debug("purescript#ide#call error: " . purescript#ide#utils#toString(err), 0)}
	\ })
  call purescript#job#send(jobid, enc . "\n")
  " call purescript#job#stop(jobid) " Not needed I think, \n stops job
endfun

fun! purescript#ide#callSync(input, errorm, isRetry)
  call purescript#ide#utils#debug("purescript#ide#callSync: command: " . json_encode(a:input), 3)

  if !s:valid
    call PSCIDEprojectValidate(v:true)
  endif

  if !s:started
    let expectedCWD = fnamemodify(purescript#ide#utils#findRoot(), ":p:h")
    let cwdcommand = {'command': 'cwd'}

    call purescript#ide#utils#debug("purescript#ide#callSync: no server found", 1)
    let cwdresp = system("purs 2>/dev/null ide client -p " . g:psc_ide_server_port, json_encode(cwdcommand))
    return s:startFn(a:input, a:errorm, 0, cwdcommand, cwdresp)
  else
    call purescript#ide#utils#debug("purescript#ide#callSync: trying to reach server again", 1)
    let enc = json_encode(a:input)
    let resp = system("purs 2>/dev/null ide client -p " . g:psc_ide_server_port, enc)
    return s:callFn(a:input, a:errorm, a:isRetry, 0, resp)
  endif
endfun

fun! s:startFn(input, errorm, cb, cwdcommand, cwdresp, ...)
  let silent = a:0 >= 1 ? a:1 : v:false

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
      if !silent
	call purescript#ide#utils#log("started", v:true)
      endif
      let s:started = v:true
      let s:external = v:true
    endif
  else
    call purescript#ide#utils#debug("s:startFn: starting new server", 1)
    call PSCIDEstart(1)
  endif
  call purescript#ide#utils#debug("s:startFn: resending", 1)
  if (type(a:cb) == type(0) && !a:cb)
    let cwdresp = system(
	  \ "purs 2>/dev/null ide client -p" . g:psc_ide_server_port,
	  \ json_encode(a:cwdcommand)
	  \ )
    call s:retryFn(a:input, a:errorm, 0, cwd, cwdresp)
  else
    let jobid = purescript#job#start(
	  \ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	  \ { "on_stdout": { ch, resp -> s:retryFn(a:input, a:errorm, a:cb, cwd, resp, silent) }
	  \ , "on_stderr": { ch, err -> silent ? purescript#ide#utils#warn(purescript#ide#utils#toString(err)) : v:null }
	  \ }
	  \)
    call purescript#job#send(jobid, json_encode(a:cwdcommand) . "\n")
  endif
endfun

fun! s:retryFn(input, errorm, cb, expectedCWD, cwdresp2, ...)
  let silent = a:0 >= 1 ? a:1 : v:false
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

  if type(cwdresp2Decoded) == v:t_dict && cwdresp2Decoded.resultType ==# 'success' 
     \ && cwdresp2Decoded.result == a:expectedCWD
    call purescript#ide#utils#debug("s:retryFn: success", 1)
    call PSCIDEload(1, "")
  else
    if type(cwdresp2Decoded) == v:t_dict
      let error = get(cwdresp2Decoded, "error", [])
      if type(error) == v:t_list && len(error) && !silent
	call purescript#ide#utils#warn(join(error, " "), v:true)
      endif
    endif
    return
  endif

  let enc = json_encode(a:input)
  if (type(a:cb) == type(0))
    let resp = system(
	  \ "purs 2>/dev/null ide client -p" . g:psc_ide_server_port,
	  \ enc
	  \ )
    return s:callFn(a:input, a:errorm, 1, 0, resp)
  endif

  if (type(a:cb) == type(0) && !a:cb)
    let resp = system(
	  \ "purs 2>/dev/null ide client -p" . g:psc_ide_server_port
	  \ enc
	  \ )
    return s:callFn(a:input, a:errorm, 1, 0, resp)
  endif
  call purescript#ide#utils#debug("callPscIde: command: " . enc, 3)
  let jobid = purescript#job#start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "on_stdout": {ch, resp -> a:cb(s:callFn(a:input, a:errorm, 1, a:cb, resp, silent))}
	\ , "on_stderr": {ch, err -> purescript#ide#utils#debug("s:retryFn error: " . err, 3)}
	\ })
  call purescript#job#send(jobid, enc . "\n")
endfun

fun! s:callFn(input, errorm, isRetry, cb, resp, ...)
  let silent = a:0 >= 1 ? a:1 : v:false
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
      if !silent
	call purescript#ide#utils#log("failed to contact server", v:true)
      endif
    else
      " Seems saving often causes `purs ide server` to crash. Haven't been able
      " to figure out why. It doesn't crash when I run it externally...
      " retrying is then the next best thing
      return purescript#ide#call(a:input, a:errorm, 1, a:cb, silent) " Keeping track of retries so we only retry once
    endif
  endtry

  if (type(decoded) != type({}) || decoded['resultType'] !=# 'success') 
      \ && type(a:errorm) == v:t_string
    call purescript#ide#utils#log(a:errorm)
  endif
  return decoded
endfun

fun! purescript#ide#handlePursError(resp)
  if type(a:resp) == v:t_dict
    call purescript#ide#utils#error(get(a:resp, "result", "error"))
  elseif type(a:resp) == v:t_string
    call purescript#ide#utils#error(a:resp)
  endif
endfun
