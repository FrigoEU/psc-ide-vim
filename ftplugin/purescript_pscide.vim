if !exists('g:psc_ide_log_level')
  let g:psc_ide_log_level = 0
endif

if !exists('g:psc_ide_suggestions')
  let g:psc_ide_suggestions = {}
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
command! PSCIDEstart call PSCIDEstart(0)
function! PSCIDEstart(silent)
  if s:pscidestarted == 1 
    return
  endif
  let loglevel = a:silent == 1 ? 1 : 0

  let dir = s:findFileRecur('bower.json')

  if dir == ''
    echom "No bower.json found, couldn't start psc-ide-server"
    return
  endif

  call s:log("PSCIDEstart: Starting psc-ide-server at ", loglevel)

  let command = (has('win16') || has('win32') || has('win64')) ? ("start /b psc-ide-server -p 4242 -d " . dir) : ("psc-ide-server -p 4242 -d " . dir . " &")
  let resp = system(command)

  call s:log("callPscIde: Sleeping for 100ms so server can start up", 1)
  :exe "sleep 100m"

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
  let resp = system("psc-ide-client -p 4242", s:jsonEncode(input))
  let s:pscidestarted = 0
endfunction

" LOAD -----------------------------------------------------------------------
" Load module of current buffer + its dependencies into psc-ide-server
command! PSCIDEload call PSCIDEload(0)
function! PSCIDEload(silent)
  let module = s:extractModule()
  let loglevel = a:silent == 1 ? 1 : 0

  if module == ''
    call s:log("No valid module declaration found", 0)
    return
  endif

  let input = {'command': 'load', 'params': {'modules': [], 'dependencies': [module]}}

  let resp = s:callPscIde(input, "Failed to load module " . module, 0)

  if type(resp) == type({}) && resp['resultType'] ==# "success"
    call s:log("PSCIDEload: Succesfully loaded modules: " . string(resp["result"]), loglevel)
  else
    call s:log("PSCIDEload: Failed to load module: " . module . ". Error: " . string(resp["result"]), loglevel)
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

" Add type annotation
command! PSCIDEaddTypeAnnotation call PSCIDEaddTypeAnnotation()
function! PSCIDEaddTypeAnnotation()
  let identifier = s:GetWordUnderCursor()

  let result = s:getType(identifier)

  if type(result) == type([])
    let lnr = line(".")
    call append(lnr - 1, s:StripNewlines(result[0]['identifier']) . ' :: ' . s:StripNewlines(result[0]["type"]))
  else
    echom "PSC-IDE: No type information found for " . identifier
  endif
endfunction

" CWD ------------------------------------------------------------------------
" Get current working directory of psc-ide-server
command! PSCIDEcwd call PSCIDEcwd()
function! PSCIDEcwd()
  let resp = s:callPscIde({'command': 'cwd'}, "Failed to get current working directory", 0)

  if type(resp) == type({}) && resp['resultType'] ==# 'success'
    echom "PSC-IDE: Current working directory: " . resp["result"]
  endif
endfunction

" ADDCLAUSE
" Makes template function implementation from signature
command! PSCIDEaddClause call PSCIDEaddClause()
function! PSCIDEaddClause()
  let lnr = line(".")
  let line = getline(lnr)

  let command = {'command': 'addClause', 'params': {'line': line, 'annotations': s:jsonFalse()}}

  let resp = s:callPscIde(command, "Failed to add clause", 0)

  if type(resp) == type({}) && resp['resultType'] ==# 'success' && type(resp.result) == type([])     
    call s:log('PSCIDEaddClause results: ' . string(resp.result), 3)
    call append(lnr, resp.result)
    :normal dd
  endif
endfunction

" CASESPLIT
" Hover cursor over variable in function declaration -> pattern match on all
" different cases of the variable
command! PSCIDEcaseSplit call PSCIDEcaseSplit()
function! PSCIDEcaseSplit()
  let lnr = line(".")
  let line = getline(lnr)

  let word = s:GetWordUnderCursor()
  let b = match(line, word)
  let e = matchend(line, word)

  let t = input("Type: ")

  call s:log('PSCIDEcaseSplit: ', 3)
  call s:log('line: ' . line, 3)
  call s:log('start position: ' . string(b), 3)
  call s:log('end position: ' . string(e), 3)
  call s:log('type: ' . t, 3)

  let command = {'command': 'caseSplit', 'params': {'line': line, 'begin': b, 'end': e, 'type': t}}

  let resp = s:callPscIde(command, 'Failed to split case for: ' . word, 0)

  if type(resp) == type({}) && resp['resultType'] ==# 'success' && type(resp.result) == type([])     
    call s:log('PSCIDEcaseSplit results: ' . string(resp.result), 3)
    call append(lnr, resp.result)
    :normal dd
  endif
endfunction

" TYPE -----------------------------------------------------------------------
" Get type of word under cursor
command! PSCIDEtype call PSCIDEtype()
function! PSCIDEtype()
  let identifier = s:GetWordUnderCursor()

  let result = s:getType(identifier)

  if type(result) == type([])
    for e in result
      echom s:formattype(e)
    endfor
  else
    echom "PSC-IDE: No type information found for " . identifier
  endif
endfunction

function! s:getType(identifier)
  let resp = s:callPscIde({'command': 'type', 'params': {'search': a:identifier, 'filters': []}}, 'Failed to get type info for: ' . a:identifier, 0)

  if type(resp) == type({}) && resp['resultType'] ==# 'success'
    if len(resp["result"]) > 0
      return resp["result"]
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
  call PSCIDEapplySuggestionPrime(lnr, bnr, 0)
endfunction
function! PSCIDEapplySuggestionPrime(lnr, bnr, silent)
  let llist = getloclist(0)

  call s:log('PSCIDEapplySuggestion: lineNr: ' . a:lnr, 3)
  call s:log('PSCIDEapplySuggestion: BufferNr: ' . a:bnr, 3)

  for entry in llist
    if entry.lnum == a:lnr && entry.bufnr == a:bnr && has_key(g:psc_ide_suggestions, string(entry.nr))
      let found = g:psc_ide_suggestions[string(entry.nr)]
    endif
  endfor

  if !exists('found')
    if !a:silent
      call s:log('PSCIDEapplySuggestion: No suggestion found', 0)
    endif
    return
  endif
  call s:log('PSCIDEapplySuggestion: Suggestion found: ' . string(found), 3)

  while found.endColumn == 1 || getline(found.endLine) == ''
    call s:log('PSCIDEapplySuggestion: endLine moved from ' . found.endLine . " to " . (found.endLine - 1) , 3)
    let found.endLine = found.endLine - 1
    let found.endColumn = len(getline(found.endLine)) + 1
  endwhile

  let lines = getline(found.startLine, found.endLine)
  call s:log('PSCIDEapplySuggestion: Lines to replace: ' . string(lines), 3)

  let newl = strpart(lines[0], 0, found.startColumn - 1) .
           \ found.replacement .
           \ strpart(lines[len(lines) - 1], found.endColumn - 1)
  call s:log('PSCIDEapplySuggestion: newl: ' . newl, 3)

  let newlines = split(newl, '\n')
  call s:log('PSCIDEapplySuggestion: newlines: ' . string(newlines), 3)

  if len(newlines) == 1
    call s:log('PSCIDEapplySuggestion: setline(' . found.startLine . ", " . newlines[0] .")", 3)
    call setline(found.startLine, newlines[0])
  else
    let command = string(found.startLine) . "," . string(found.endLine) . "d"
    call s:log('PSCIDEapplySuggestion: exe ' . command , 3)
    :exe command
    call s:log('PSCIDEapplySuggestion: append(' . (found.startLine - 1) . ", " . string(newlines) . ")", 3)
    call append(found.startLine - 1, newlines)
  endif
endfunction

" Remove all import qualifications
command! PSCIDEremoveImportQualifications call PSCIDEremoveImportQualifications()
function! PSCIDEremoveImportQualifications()
  let captureregex = "import\\s\\(\\S\\+\\)\\s*(.*)"
  let replace = "import \\1"
  let command = "silent %s:" . captureregex . ":" . replace . ":g|norm!``"
  call s:log('Executing PSCIDEremoveImportQualifications command: ' . command, 3)
  :exe command
endfunction

" Add all import qualifications
command! PSCIDEaddImportQualifications call PSCIDEaddImportQualifications()
function! PSCIDEaddImportQualifications()
  let foundLines = []
  let bnr = bufnr("%")
  let oldCursorPos = getcurpos()

  call cursor(1, 0)
  let found = searchpos("import", "W")
  while found != [0,0]
    let foundLines = insert(foundLines, found[0]) " Insert = unshift -> list is in reverse = what we want because of deleting
    call cursor(found[0], 0)
    let found = searchpos("import", "W")
  endwhile
  call s:log('Adding import qualifications to : ' . string(foundLines), 3)

  for lnr in foundLines
    call PSCIDEapplySuggestionPrime(lnr, bnr, 1)
  endfor

  call cursor(oldCursorPos[1], oldCursorPos[2])
endfunction


" PURSUIT --------------------------------------------------------------------
command! PSCIDEpursuit call PSCIDEpursuit()
function! PSCIDEpursuit()
  let identifier = s:GetWordUnderCursor()

  let resp = s:callPscIde({'command': 'pursuit', 'params': {'query': identifier, 'type': "completion"}}, 'Failed to get pursuit info for: ' . identifier, 0)

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
  let resp = s:callPscIde({'command': 'list', 'params': {'type': 'loadedModules'}}, 'Failed to get loaded modules', 0)

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

    let resp = s:callPscIde({'command': 'complete', 'params': {'filters': [s:prefixFilter(str)], 'matcher': s:flexMatcher(str)}}, 'Failed to get completions for: ' . str, 0)

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
function! s:callPscIde(input, errorm, retry)
  call s:log("callPscIde: start: Executing command: " . string(a:input), 3)

  if s:pscidestarted == 0

    let expectedCWD = s:findFileRecur('bower.json')
    let cwdcommand = {'command': 'cwd'}

    call s:log("callPscIde: No server found, looking for external server", 1)
    let cwdresp = s:jsonDecode(system("psc-ide-client -p 4242 ", s:jsonEncode(cwdcommand)))
    if type(cwdresp) == type({}) && cwdresp.resultType ==# 'success'
      call s:log("callPscIde: Found external server with cwd: " . string(cwdresp.result), 1)
      call s:log("callPscIde: Expecting CWD: " . expectedCWD, 1)

      if expectedCWD != cwdresp.result
        call s:log("callPscIde: External server on incorrect CWD, closing", 1)
        PSCIDEend
        call s:log("callPscIde: Starting new server", 1)
        call PSCIDEstart(1)
      else
        call s:log("callPscIde: External server CWD matches with what we need", 1)
        let s:pscidestarted = 1
        let s:pscideexternal = 1
      endif
    else
      call s:log("callPscIde: No external server found, starting new server", 1)
      call PSCIDEstart(1)
    endif

    call s:log("callPscIde: Trying to reach server again", 1)
    let cwdresp2 = s:jsonDecode(system("psc-ide-client -p 4242 ", s:jsonEncode(cwdcommand)))

    if type(cwdresp2) == type({}) && cwdresp2.resultType ==# 'success' && cwdresp2.result == expectedCWD
      call s:log("callPscIde: Server successfully contacted! Loading current module.", 1)
      call PSCIDEload(1)
    else
      call s:log("callPscIde: Server still can't be contacted, aborting...", 1)
      return
    endif
  endif

  let resp = system("psc-ide-client -p 4242 ", s:jsonEncode(a:input))
  call s:log("callPscIde: Raw response: " . resp, 3)

  if resp =~ "onnection refused"  "TODO: This check is probably not crossplatform
    let s:pscidestarted = 0
    let s:pscideexternal = 0

    if a:retry
      call s:log("callPscIde: Error: Failed to contact server", 0)
    endif
    if !a:retry
      " Seems saving often causes psc-ide-server to crash. Haven't been able
      " to figure out why. It doesn't crash when I run it externally...
      " Retrying is then the next best thing
      return s:callPscIde(a:input, a:errorm, 1) " Keeping track of retries so we only retry once
    endif
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
  autocmd BufWritePost *.purs call s:AutoLoad()
augroup END
function! s:AutoLoad()
  if s:pscidestarted == 1
    silent PSCIDEload
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

