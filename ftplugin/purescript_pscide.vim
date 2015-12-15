" START ----------------------------------------------------------------------
if !exists('s:pscidestarted')
  let s:pscidestarted = 0
endif
if !exists('s:pscideexternal')
  let s:pscideexternal = 0
endif

"Looks for bower.json, assumes that's the root directory, starts
"psc-ide-server in the background
"Returns Nothing
command! PSCIDEstart call PSCIDEstart()
function! PSCIDEstart()
  if s:pscidestarted == 1 
    return
  endif
  let iteration = 0
  let list = []
  let dir = ''
  echom "starting psc-ide-server"

  " Climbing up on the file tree until we find a bower.json
  while (len(list) == 0 && iteration < 10)
    let iteration += 1
    if iteration == 1
      let pattern = '.'
    elseif iteration == 2
      let pattern = '..'
    else
      let pattern = (has('win16') || has('win32') || has('win64')) ? pattern + '\..' : pattern + '/..'
    endif

    let list = globpath(pattern, "bower.json", 1, 1)
  endwhile

  if len(list) > 0
    let dir = fnamemodify(list[0], ':p:h')
  else
    echom "No bower.json found, couldn't start psc-ide-server"
    return
  endif

  let command = (has('win16') || has('win32') || has('win64')) ? ("start /b psc-ide-server -p 4242 -d " . dir) : ("psc-ide-server -p 4242 -d " . dir . " &")
  let resp = system(command)
  let s:pscidestarted = 1
endfunction

" END ------------------------------------------------------------------------
" Tell the psc-ide-server to quit
command! PSCIDEend call PSCIDEend()
function! PSCIDEend()
  if s:pscideexternal == 1
    return
  endif
  let input = {'command': 'quit'}
  let resp = system("psc-ide -p 4242", s:jsonEncode(input))
  let s:pscidestarted = 0
endfunction

" LOAD -----------------------------------------------------------------------
" Load module of current buffer + its dependencies into psc-ide-server
command! PSCIDEload call PSCIDEload()
function! PSCIDEload()
  " Find the module we're currently in. Don't know how to get the length of
  " the current buffer so just looking at the first 20 lines, should be enough
  let module = ''
  let iteration = 0
  while module == '' && iteration < 20
    let iteration += 1
    let line = getline(iteration)
    let matches = matchlist(line, 'module\s\(\S*\)')
    if len(matches) > 0
      let module = matches[1]
    endif
  endwhile

  if module == ''
    echom "No valid module declaration found"
    return
  endif

  let input = {'command': 'load', 'params': {'modules': [], 'dependencies': [module]}}

  let resp = system("psc-ide -p 4242", s:jsonEncode(input))
  let decoded = s:jsonDecode(resp)

  if (decoded['resultType'] ==# "success")
    echom decoded['result']
  else
    echom "Failed to load module: " . module . ". Error: " decoded["result"]
  endif
endfunction

" CWD ------------------------------------------------------------------------
" Get current working directory of psc-ide-server
command! PSCIDEcwd call PSCIDEcwd()
function! PSCIDEcwd()
  let input = {'command': 'cwd'}
  let resp = system("psc-ide -p 4242", s:jsonEncode(input))
  let decoded = s:jsonDecode(resp)
  echom "PSC-IDE: Current working directory: " . decoded["result"]
endfunction

" TYPE -----------------------------------------------------------------------
" Get type of word under cursor
command! PSCIDEtype call PSCIDEtype()
function! PSCIDEtype()
  let identifier = s:GetWordUnderCursor()

  let resp = s:callPscIde({'command': 'type', 'params': {'search': identifier, 'filters': []}}, 'Failed to get type info for: ' . identifier)

  if resp['resultType'] ==# 'success'
    if len(resp["result"]) > 0
      " echom 'PSC-IDE: Type: '
      for e in resp["result"]
        echom s:format(e)
      endfor
    else
      echom "PSC-IDE: No type information found for " . identifier
    endif
  endif
endfunction

" Experiment: Substitute suggestion into file --------------------------------
command! PSCIDEsubstitute call PSCIDEsubstitute()
function! PSCIDEsubstitute()
  let lnr = line(".")
  let bnr = bufnr("%")
  let llist = getloclist(0)

  for entry in llist
    if entry.lnum == lnr && entry.bufnr == bnr
      let found = entry
    endif
  endfor

  if exists("found")
    let matches = matchlist(found.text, 'explicit\sform\:\s\?\(.*\)\s\?See')
    if len(matches) > 0
      call setline(lnr, matches[1])
      return
    endif

    let matches = matchlist(found.text, 'inferred\stype\sof\s\(.*\)\swas\:\(.*\)in\svalue')
    if len(matches) > 0
      call append(lnr-1, matches[1] . " ::" . matches[2])
      return
    endif

    let matches = matchlist(found.text, 'import.*redundant')
    if len(matches) > 0
      :normal dd
      return
    endif
    
    let unusedMatches = matchlist(found.text, 'unused\sreferences\:\s\(\w\+\s\)')
    if len(unusedMatches) > 0
      call remove(unusedMatches, 0)
      let unused = filter(unusedMatches, "v:val != ''")
      let importListPattern = '\((.*)\)'
      let importListMatches = matchlist(getline(lnr), importListPattern)

      if len(importListMatches) > 0
        let o = importListMatches[1]
        for u in unused
          let substitution = '\s*' . 
                           \ '\<' . 
                           \ s:CleanEnd(u) . 
                           \ '\>' . 
                           \ '\s*' . 
                           \ '\((.\{-})\)\?' .
                           \ '\C' 
          let o = substitute(o, substitution, '', '')
        endfor
        let o = substitute(o, '(\s*,\s*', '(', 'g')
        let o = substitute(o, '\s*,\s*)', ')', 'g')
        let o = substitute(o, ',\s*,', ',', 'g')
        let out = substitute(getline(lnr), importListPattern, o, 'g')
        call setline(lnr, out)
      else 
        " Bad times, we can't find the import list
      endif
      return
    endif
    
    echom "PSCIDEsubstitute: No suggestion found on current line 1"
  else
    echom "PSCIDEsubstitute: No suggestion found on current line 2"
  endif
endfunction

" PURSUIT --------------------------------------------------------------------
command! PSCIDEpursuit call PSCIDEpursuit()
function! PSCIDEpursuit()
  let identifier = s:GetWordUnderCursor()

  let resp = s:callPscIde({'command': 'pursuit', 'params': {'query': identifier, 'type': "completion"}}, 'Failed to get pursuit info for: ' . identifier)

  if resp['resultType'] ==# 'success'
    if len(resp["result"]) > 0
      " echom 'PSC-IDE: Pursuit results:'
      for e in resp["result"]
        echom s:formatpursuit(e)
      endfor
    else
      echom "PSC-IDE: No results found on Pursuit"
    endif
  endif
endfunction

" LIST -----------------------------------------------------------------------
command! PSCIDElist call PSCIDElist()
function! PSCIDElist()
  let resp = s:callPscIde({'command': 'list', 'params': {'type': 'loadedModules'}}, 'Failed to get loaded modules')

  if resp['resultType'] ==# 'success'
    if len(resp["result"]) > 0
      " echom 'PSC-IDE: Loaded modules: '
      for m in resp["result"]
        echom m
      endfor
    else
      echom "PSC-IDE: No loaded modules found"
  endif
endfunction


" SET UP OMNICOMPLETION ------------------------------------------------------
aug PSCIDE
  au!
  au BufNewFile,BufRead *.purs setlocal omnifunc=PSCIDEomni
aug PSCIDE
doau PSCIDE BufRead

" OMNICOMPLETION FUNCTION ----------------------------------------------------
"Omnicompletion function
function! PSCIDEomni(findstart,base)
  let col   = col(".")
  let line  = getline(".")

  " search backwards for start of identifier (iskeyword pattern)
  let start = col
  while start>0 && (line[start-2] =~ "\\k" || line[start-2] =~ "\\.")
    let start -= 1
  endwhile

  if a:findstart 
    "Looking for the start of the identifier that we want to complete
    return start-1
  else
    "echom 'completing second round: ' . a:base

    let entries = PSCIDEGetCompletions(a:base)

    "Popuplating the omnicompletion list
    let result = []
    if type(entries)==type([])
      for entry in entries
        if entry['identifier'] =~ '^'.a:base
          call add(result, {'word': entry['identifier'], 'menu': s:StripNewlines(entry['type'])
                          \,'info': entry['module'] . "." . entry['identifier']})
        endif
      endfor
    endif
    "for r in result
      "echom s:jsonEncode(r)
    "endfor
    return result
  endif
endfunction

" GET COMPLETIONS ------------------------------------------------------------
"returns list of {module, identifier, type}
function! PSCIDEGetCompletions(s)
  let resp = s:callPscIde({'command': 'complete', 'params': {'filters': [s:prefixFilter(a:s)], 'matcher': s:flexMatcher(a:s)}}, 'Failed to get completions for: ' . a:s)

  if resp['resultType'] ==# 'success'
    return resp["result"]
  endif
endfunction

function! s:prefixFilter(s) 
  return {"filter": "prefix", "params": { "search": a:s } }
endfunction

function! s:flexMatcher(s)
  return {"matcher": "flex", "params": {"search": a:s} }
endfunction

function! s:format(record)
  return s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['identifier']) . ' :: ' . s:StripNewlines(a:record['type']))
endfunction
function! s:formatpursuit(record)
  return s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['ident']) . ' :: ' . s:StripNewlines(a:record['type']))
endfunction

" PSCIDE HELPER FUNCTION -----------------------------------------------------
" Issues the commands to the server
" Is responsible for keeping track of whether or not we have a running server
" and (re)starting it if not
" Also serializes and deserializes from/to JSON
function! s:callPscIde(input, errorm)
  "silent PSCIDEload
  let resp = system("psc-ide -p 4242 ", s:jsonEncode(a:input))
  if resp =~ "Couldn't connect to psc-ide-server"
    "No server, let's try and (re)start it
    let s:pscidestarted = 0
    PSCIDEstart

    let resp = system("psc-ide -p 4242 ", s:jsonEncode(a:input))
    if resp =~ "Couldn't connect to psc-ide-server"
      "Tried but failed to start the server
      let s:pscidestarted = 0
      echom "No PSC IDE Server running and failed to start one"
    else 
      "Succesfully started server
      silent! PSCIDEload
      echom "Succesfully started psc-ide-server!"
      let resp = system("psc-ide -p 4242 ", s:jsonEncode(a:input))
    endif
  endif

  let decoded = s:jsonDecode(resp)

  if decoded['resultType'] ==# 'success' && s:pscidestarted == 0 && s:pscideexternal == 0
    "We are getting a succesful response but we didn't start the server
    "ourselves -> exteral server present
    "We're logging this in a variable so we don't shut down the external
    "server on shutdown
    let s:pscidestarted = 1
    let s:pscideexternal = 1
    silent! PSCIDEload
  endif

  if decoded['resultType'] !=# 'success'
    echom a:errorm
  endif
  return decoded
endfunction

" UTILITY FUNCTIONS ----------------------------------------------------------
function! s:StripNewlines(s)
  return substitute(a:s, '\s*\n\s*', ' ', 'g')
endfunction

function! s:CleanEnd(s)
  return substitute(a:s, '\s*\n*\s*$', '', 'g')
endfunction

function! s:GetWordUnderCursor()
  return expand("<cword>")
endfunction

" INIT -----------------------------------------------------------------------
" Automatically load the module we just opened
augroup PscIdeAutoLoad
  au!
  autocmd BufEnter *.purs call s:AutoLoad()
augroup END
function! s:AutoLoad()
  if s:pscidestarted == 1
    silent! PSCIDEload
  endif
endfunction

" Automatically close the server when leaving vim
augroup PscideShutDown
  au!
  autocmd VimLeavePre * call s:Shutdown()
augroup END
function! s:Shutdown()
  silent PSCIDEend
endfunction






" JSON ENCODING/DECODING -----------------------------------------------------
" MarcWeber/vim-addon-json-encoding
"
" Vim was ahead of its time :-) It spoke JSON before the Web discovered it -
" Well almost.
" Vim does not know about:
" true,false,null
" 
" Thus those values are represented as Vim functions.
"
" Because it can parse JSON natively when assigning true, false, null to
" values this is probably the fastest way to interface with external tools.
" The default implementation assigns:
" true  -> 1 (=vim value for true)
" false -> 0 (=vim value for false)
" null  -> 0 (=vims return value for procedures which is semantically
" similar to null - Yes, this is an arbitrary choice)
fun! s:jsonNULL()
  " return function("s:jsonNULL")
  return {'json_special_value': 'null'}
endf
fun! s:jsonTrue()
  " return function("s:jsonTrue")
  return {'json_special_value': 'true'}
endf
fun! s:jsonFalse()
  " return function("s:jsonFalse")
  return {'json_special_value': 'false'}
endf
fun! s:jsonToJSONBool(i)
  return  a:i ? s:jsonTrue() : s:jsonFalse()
endf

" optional arg: if true then append \n to , of top level dict
fun! s:jsonEncode(thing, ...)
  let nl = a:0 > 0 ? (a:1 ? "\n" : "") : ""
  if type(a:thing) == type("")
    return '"'.escape(a:thing,'"\').'"'
  elseif type(a:thing) == type({}) && !has_key(a:thing, 'json_special_value')
    let pairs = []
    for [Key, Value] in items(a:thing)
      call add(pairs, s:jsonEncode(Key).':'.s:jsonEncode(Value))
      unlet Key | unlet Value
    endfor
    return "{".nl.join(pairs, ",".nl)."}"
  elseif type(a:thing) == type(0)
    return a:thing
  elseif type(a:thing) == type([])
    return '['.join(map(copy(a:thing), "s:jsonEncode(v:val)"),",").']'
    return 
  elseif string(a:thing) == string(s:jsonNULL())
    return "null"
  elseif string(a:thing) == string(s:jsonTrue())
    return "true"
  elseif string(a:thing) == string(s:jsonFalse())
    return "false"
  else
    throw "unexpected new thing: ".string(a:thing)
  endif
endf

" if you want s:jsonEncode(s:jsonDecode(str)) == str
" then you have to assign true to s:jsonTrue() etc.
" I don't have a use case so I use Vim encoding

fun! s:jsonDecode(s)
  let true = 1
  let false = 0
  let null = 0
  return eval(s:CleanEnd(a:s))
endf

fun! s:jsonDecodePreserve(s)
  let true = s:jsonTrue()
  let false = s:jsonFalse()
  let null = s:jsonNULL()
  return eval(s:CleanEnd(a:s))
endf

