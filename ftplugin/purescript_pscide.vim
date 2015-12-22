if !exists('g:psc_ide_log_level')
  let g:psc_ide_log_level = 0
endif

" Syntastic initialization ---------------------------------------------------
if exists('g:syntastic_extra_filetypes')
  call add(g:syntastic_extra_filetypes, 'purescript')
else
  let g:syntastic_extra_filetypes = ['purescript']
endif


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
  echom "PSCIDEstart: Starting psc-ide-server"

  let dir = s:findFileRecur('bower.json')

  if dir == ''
    echom "No bower.json found, couldn't start psc-ide-server"
    return
  endif

  let command = (has('win16') || has('win32') || has('win64')) ? ("start /b psc-ide-server -p 4242 -d " . dir) : ("psc-ide-server -p 4242 -d " . dir . " &")
  let resp = system(command)
  let s:pscidestarted = 1
endfunction

" Find file recursively, return folder ----------------------------------------------------
function! s:findFileRecur(filename)
  let iteration = 0
  let list = []
  let dir = ''

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

    let list = globpath(pattern, a:filename, 1, 1)
  endwhile

  if len(list) > 0
    return fnamemodify(list[0], ':p:h')
  else
    return ''
  endif
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
  let module = s:extractModule()

  if module == ''
    echom "No valid module declaration found"
    return
  endif

  let input = {'command': 'load', 'params': {'modules': [], 'dependencies': [module]}}

  let resp = s:callPscIde(input, "Failed to load module " . module)

  if type(resp) == type({}) && resp['resultType'] ==# "success"
    call s:log("PSCIDEload: Succesfully loaded modules: " . string(resp["result"]), 0)
  else
    call s:log("PSCIDEload: Failed to load module: " . module . ". Error: " string(resp["result"]), 0)
  endif
endfunction

function! s:extractModule()
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

  return module
endfunction

" CWD ------------------------------------------------------------------------
" Get current working directory of psc-ide-server
command! PSCIDEcwd call PSCIDEcwd()
function! PSCIDEcwd()
  let resp = s:callPscIde({'command': 'cwd'}, "Failed to get current working directory")

  if type(resp) == type({}) && resp['resultType'] ==# 'success'
    echom "PSC-IDE: Current working directory: " . resp["result"]
  endif
endfunction

" TYPE -----------------------------------------------------------------------
" Get type of word under cursor
command! PSCIDEtype call PSCIDEtype()
function! PSCIDEtype()
  let identifier = s:GetWordUnderCursor()

  let resp = s:callPscIde({'command': 'type', 'params': {'search': identifier, 'filters': []}}, 'Failed to get type info for: ' . identifier)

  if type(resp) == type({}) && resp['resultType'] ==# 'success'
    if len(resp["result"]) > 0
      " echom 'PSC-IDE: Type: '
      for e in resp["result"]
        echom s:formattype(e)
      endfor
    else
      echom "PSC-IDE: No type information found for " . identifier
    endif
  endif
endfunction
function! s:formattype(record)
  return s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['identifier']) . ' :: ' . s:StripNewlines(a:record['type']))
endfunction


" APPLYSUGGESTION ------------------------------------------------------
" Apply suggestion in loclist to buffer --------------------------------
command! PSCIDEapplySuggestion call PSCIDEapplySuggestion()
function! PSCIDEapplySuggestion()
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

    let matches = matchlist(found.text, 'inferred' . '\s' . 'type' . '\s' . 'of'. '\s' . '\(.*\)' . '\s' . 'was\:' . '\(.*\)'. 'in' . '\s'. 'value')
    if len(matches) > 0
      call append(lnr-1, matches[1] . " ::" . matches[2])
      return
    endif

    let matches = matchlist(found.text, 'import.*redundant')
    if len(matches) > 0
      :normal dd
      return
    endif
    
    let unusedMatches = matchlist(found.text, 'unused\sreferences\:' . '\s' . '\(\(\w\+\s\)\+\)' . 'See')
    if len(unusedMatches) > 0
      let unusedToSplit = unusedMatches[1]
      let unusedSplit = split(unusedToSplit, " ")
      let unused = filter(unusedSplit, "v:val != ''")
      let importListPattern = '\((.*)\)'
      let importListMatches = matchlist(getline(lnr), importListPattern)

      if len(importListMatches) > 0
        let o = importListMatches[1]
        for u in unused
          let substitution = '\s*' . 
                           \ '\<' . 
                           \ u . 
                           \ '\>' . 
                           \ '\s*' . 
                           \ '\((.\{-})\)\?' .
                           \ '\C' 
          let o = substitute(o, substitution, '', '')
        endfor
        let o = substitute(o, ',\s*,\+', ',', 'g')
        let o = substitute(o, '(\s*,\s*', '(', 'g')
        let o = substitute(o, '\s*,\s*)', ')', 'g')
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

  if type(resp) == type({}) && resp['resultType'] ==# 'success'
    if len(resp["result"]) > 0
      for e in resp["result"]
        echom s:formatpursuit(e)
      endfor
    else
      echom "PSC-IDE: No results found on Pursuit"
    endif
  endif
endfunction
function! s:formatpursuit(record)
  return "In " . s:CleanEnd(s:StripNewlines(a:record["package"])) . " " . s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['ident']) . ' :: ' . s:StripNewlines(a:record['type']))
endfunction

" LIST -----------------------------------------------------------------------
command! PSCIDElist call PSCIDElist()
function! PSCIDElist()
  let resp = s:callPscIde({'command': 'list', 'params': {'type': 'loadedModules'}}, 'Failed to get loaded modules')

  if type(resp) == type({}) && resp['resultType'] ==# 'success'
    if len(resp["result"]) > 0
      for m in resp["result"]
        echom m
      endfor
    else
      echom "PSC-IDE: No loaded modules found"
    endif
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
  if a:findstart 
    let col   = col(".")
    let line  = getline(".")

    " search backwards for start of identifier (iskeyword pattern)
    let start = col
    while start>0 && (line[start-2] =~ "\\k" || line[start-2] =~ "\\.")
      let start -= 1
    endwhile

    "Looking for the start of the identifier that we want to complete
    return start-1
  else
    let str = type(a:base) == type('a') ? a:base : string(a:base)
    call s:log('PSCIDEOmni: Looking for completions for: ' . str, 3)

    let resp = s:callPscIde({'command': 'complete', 'params': {'filters': [s:prefixFilter(str)], 'matcher': s:flexMatcher(str)}}, 'Failed to get completions for: ' . str)

    if type(resp) == type({}) && resp.resultType ==# 'success'
      call s:log('PSCIDEOmni: Found Entries: ' . string(resp.result), 3)
      let entries = resp["result"] "Entries = list of {module, identifier, type}
    else 
      let entries = []
    endif

    "Popuplating the omnicompletion list
    let result = []
    if type(entries)==type([])
      for entry in entries
        if entry['identifier'] =~ '^' . str
          call add(result, {'word': entry['identifier'], 'menu': s:StripNewlines(entry['type'])
                          \,'info': entry['module'] . "." . entry['identifier']})
        endif
      endfor
    endif
    return result
  endif
endfunction

function! s:prefixFilter(s) 
  return {"filter": "prefix", "params": { "search": a:s } }
endfunction

function! s:flexMatcher(s)
  return {"matcher": "flex", "params": {"search": a:s} }
endfunction

" PSCIDE HELPER FUNCTION -----------------------------------------------------
" Issues the commands to the server
" Is responsible for keeping track of whether or not we have a running server
" and (re)starting it if not
" Also serializes and deserializes from/to JSON
function! s:callPscIde(input, errorm)
  call s:log("callPscIde: Executing command: " . string(a:input), 3)

  if !s:pscidestarted
    call s:log("callPscIde: No server found, looking for external server", 1)

    let expectedCWD = s:findFileRecur('bower.json')
    let cwdcommand = {'command': 'cwd'}
    let cwdresp = s:jsonDecode(system("psc-ide -p 4242 ", s:jsonEncode(cwdcommand)))
    if type(cwdresp) == type({}) && cwdresp.resultType ==# 'success'
      call s:log("callPscIde: Found external server with cwd: " . string(cwdresp.result), 1)
      call s:log("callPscIde: Expecting CWD: " . expectedCWD, 1)

      if expectedCWD != cwdresp.result
        call s:log("callPscIde: External server on incorrect CWD, closing", 1)
        PSCIDEend
        call s:log("callPscIde: Starting new server", 1)
        PSCIDEstart
        call s:log("callPscIde: Loading current module", 1)
        PSCIDEload
      else
        call s:log("callPscIde: External server CWD matches with what we need, loading current module", 1)
        let s:pscidestarted = 1
        let s:pscideexternal = 1
        PSCIDEload
      endif
    else
      call s:log("callPscIde: No external server found, starting new server", 1)
      PSCIDEstart
      call s:log("callPscIde: Loading current module", 1)
      PSCIDEload
    endif

    call s:log("callPscIde: Trying to reach server again", 1)

    let cwdresp2 = s:jsonDecode(system("psc-ide -p 4242 ", s:jsonEncode(cwdcommand)))
    if type(cwdresp2) == type({}) && cwdresp2.resultType ==# 'success' && cwdresp2.result == expectedCWD
      call s:log("callPscIde: Server successfully contacted!", 1)
    else
      call s:log("callPscIde: Server still can't be contacted, aborting...", 1)
      return
    endif
  endif

  let resp = system("psc-ide -p 4242 ", s:jsonEncode(a:input))
  call s:log("callPscIde: Raw response: " . resp, 3)

  if resp =~ "onnection refused"  "TODO: This check is probably not crossplatform
    call s:log("callPscIde: Error: Failed to contact server", 0)
    let s:pscidestarted = 0
    let s:pscideexternal = 0
  endif

  let decoded = s:jsonDecode(s:CleanEnd(s:StripNewlines(resp)))
  call s:log("callPscIde: Decoded response: " . string(decoded), 3)

  if type(decoded) != type({}) || decoded['resultType'] !=# 'success'
    call s:log("callPscIde: Error: " . a:errorm, 0)
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

function! s:log(str, level)
  if g:psc_ide_log_level >= a:level
    echom a:str
  endif
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






fun! s:jsonNULL()
  return {'json_special_value': 'null'}
endf
fun! s:jsonTrue()
  return {'json_special_value': 'true'}
endf
fun! s:jsonFalse()
  return {'json_special_value': 'false'}
endf
fun! s:jsonToJSONBool(i)
  return  a:i ? s:jsonTrue() : s:jsonFalse()
endf

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

function! s:jsonDecode(json) abort
  let cleaned = s:CleanEnd(a:json)
    if a:json ==# ''
        return []
    endif

    if substitute(cleaned, '\v\"%(\\.|[^"\\])*\"|true|false|null|[+-]?\d+%(\.\d+%([Ee][+-]?\d+)?)?', '', 'g') !~# "[^,:{}[\\] \t]"
        " JSON artifacts
        let true = 1
        let false = 0
        let null = ''

        try
            let object = eval(cleaned)
        catch
            " malformed JSON
            let object = ''
        endtry
    else
        let object = ''
    endif

    return object
endfunction 

