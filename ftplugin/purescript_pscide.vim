" Inits ----------------------------------------------------------------------
if exists('g:loaded_psc_ide_vim')
  finish
endif
let g:loaded_psc_ide_vim = 1

let s:tempfile = tempname()

if !exists('g:psc_ide_suggestions')
  let g:psc_ide_suggestions = {}
endif

" Options -------------------------------------------------------------------
if !exists('g:psc_ide_log_level')
  let g:psc_ide_log_level = 0
endif

if !exists('g:psc_ide_auto_imports')
  let g:psc_ide_auto_imports = 0
endif

if !exists('g:psc_ide_server_port')
  let g:psc_ide_server_port = 4242
endif

" Adding iskeyword symbols to improve GetWordUnderCursor ---------------------
" 124 = |
setlocal iskeyword+=<,>,$,#,+,-,*,/,%,',&,=,!,:,124,^

" Syntastic initialization ---------------------------------------------------
if exists('g:syntastic_extra_filetypes')
  call add(g:syntastic_extra_filetypes, 'purescript')
else
  let g:syntastic_extra_filetypes = ['purescript']
endif

let g:syntastic_purescript_checkers = ['pscide']

" START ----------------------------------------------------------------------
if !exists('s:pscidestarted')
  let s:pscidestarted = 0
endif
if !exists('s:pscideexternal')
  let s:pscideexternal = 0
endif
if !exists('s:projectvalid')
  let s:projectvalid = 0
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

  call s:log("PSCIDEstart: Starting psc-ide-server at " . dir . " on port " . g:psc_ide_server_port, loglevel)

  if has('win16') || has('win32') || has('win64')
    let command = "start /b psc-ide-server " . dir . "/src/**/*.purs " . dir . "/bower_components/**/*.purs -p " . g:psc_ide_server_port . " -d " . dir
  else
    let command = "psc-ide-server " . dir . "/src/**/*.purs " . dir . "/bower_components/**/*.purs -p " . g:psc_ide_server_port . " -d " . dir . " > /dev/null &"
  endif
  let resp = system(command)

  call s:log("PSCIDEstart: Sleeping for 100ms so server can start up", 1)
  :exe "sleep 100m"

  let s:pscidestarted = 1
endfunction

if v:version > 704 || (v:version == 704 && has('patch279'))
  function! s:globpath(dir, pattern) abort
    return globpath(a:dir, a:pattern, 1, 1)
  endfunction
else
  function! s:globpath(dir, pattern) abort
    return split(globpath(a:dir, a:pattern, 1), '\n')
  endfunction
endif



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
      let pattern = (has('win16') || has('win32') || has('win64')) ? pattern . '\..' : pattern . '/..'
    endif

    let list = s:globpath(pattern, a:filename)

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
  let resp = s:mysystem("psc-ide-client -p " . g:psc_ide_server_port, s:jsonEncode(input))
  let s:pscidestarted = 0
  let s:projectvalid = 0
endfunction

function! s:projectProblems()
  let bowerdir = s:findFileRecur('bower.json')
  let problems = []

  if bowerdir == ""
    let problem = "Your project is missing a bower.json file"
    call add(problems, problem)
  else
    let outputcontent = s:globpath(bowerdir, "output/*")
    if len(outputcontent) == 0
      let problem = "Your project's /output directory is empty.  You should run `pulp build` to compile your project."
      call add(problems, problem)
    endif
  endif

  return problems
endfunction

" LOAD -----------------------------------------------------------------------
" Load module of current buffer + its dependencies into psc-ide-server
command! PSCIDEload call PSCIDEload(0)
function! PSCIDEload(silent)
  let loglevel = a:silent == 1 ? 1 : 0

  let input = {'command': 'load'}

  let resp = s:callPscIde(input, "Failed to load", 0)

  if type(resp) == type({}) && resp['resultType'] ==# "success"
    call s:log("PSCIDEload: Succesfully loaded modules: " . string(resp["result"]), loglevel)
  else
    call s:log("PSCIDEload: Failed to load. Error: " . string(resp["result"]), loglevel)
  endif
endfunction

function! s:ExtractModule()
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

" Import given identifier
command! PSCIDEimportIdentifier call PSCIDEimportIdentifier()
function! PSCIDEimportIdentifier()
  call s:importIdentifier(s:GetWordUnderCursor(), "")
endfunction
function! s:importIdentifier(id, module)
  let ident = a:id

  call s:log('PSCIDEimportIdentifier', 3)
  call s:log('ident: ' . ident, 3)
  call s:log('s:tempfile: ' . s:tempfile, 3)

  if (ident == "")
    return
  endif

  let oldlines = getline(1, '$')

  call writefile(oldlines, s:tempfile)

  let input = { 
        \ 'command': 'import' ,
        \ 'params': {
        \   'file': s:tempfile, 
        \   'importCommand': {
        \     'importCommand': 'addImport',
        \     'identifier': ident
        \ } } }

  if a:module != ""
    let input.params.filters = [{'filter': 'modules', 'params': {'modules': [a:module]}}]
  endif

  let resp = s:callPscIde(input, "Failed to import identifier " . ident, 0)

  "multiple possibilities
  if type(resp) == type({}) && resp.resultType ==# "success" && type(resp.result[0]) == type({})
    let choices = copy(resp.result)
    call map (choices, 'v:key. v:val["module"]')
    let choice = confirm("Multiple possibilities to import " . ident , join(choices, "\n"))
    if choice
      call s:importIdentifier(ident, resp.result[choice - 1].module)
    endif
    return
  endif

  if type(resp) == type({}) && resp['resultType'] ==# "success"
    let newlines = resp.result

    let linesdiff = len(newlines) - len(oldlines)
    let nrOfOldlinesUnderLine = line(".") - 1
    let nrOfNewlinesUnderLine = nrOfOldlinesUnderLine + linesdiff
    let nrOfLinesToReplace = min([nrOfNewlinesUnderLine, nrOfOldlinesUnderLine])
    let nrOfLinesToDelete = -min([0, linesdiff])
    let nrOfLinesToAppend = max([0, linesdiff])

    call s:log('linesdiff: ' . linesdiff, 3)
    call s:log('nrOfOldlinesUnderLine: ' . nrOfOldlinesUnderLine, 3)
    call s:log('nrOfNewlinesUnderLine: ' . nrOfNewlinesUnderLine, 3)
    call s:log('nrOfLinesToReplace: ' . nrOfLinesToReplace, 3)
    call s:log('nrOfLinesToDelete: ' . nrOfLinesToDelete, 3)
    call s:log('nrOfLinesToAppend: ' . nrOfLinesToAppend, 3)

    let oldCursorPos = getcurpos()

    " Adding one at a time with setline + append/delete to keep line symbols and
    " cursor as intact as possible
    call setline(1, s:take(newlines, nrOfLinesToReplace))

    if (nrOfLinesToDelete > 0)
      let comm = 'silent ' . (nrOfLinesToReplace + 1) . "," . (nrOfLinesToReplace + nrOfLinesToDelete) . "d|0"
      :exe comm
      call cursor(oldCursorPos[1] - nrOfLinesToDelete, oldCursorPos[2])
    endif
    if (nrOfLinesToAppend > 0)
      let linesToAppend = s:take(s:drop(newlines, nrOfLinesToReplace), nrOfLinesToAppend)
      call s:log('linesToAppend: ' . string(linesToAppend), 3)
      call append(nrOfOldlinesUnderLine, linesToAppend)
    endif

    call s:log("PSCIDEimportIdentifier: Succesfully imported identifier: " . a:module . " ".a:id, 3)
  else
    call s:log("PSCIDEimportIdentifier: Failed to import identifier " . ident . ". Error: " . string(resp["result"]), 0)
  endif
endfunction

function! s:take(list, j)
  let newlist = []
  for i in range(0, a:j - 1)
    call add(newlist, a:list[i])
  endfor
  return newlist
endfunction

function! s:drop(list, j)
  let newlist = []
  for i in range(0, len(a:list) - 1)
    if i >= a:j
      call add(newlist, a:list[i])
    endif
  endfor
  return newlist
endfunction

command! PSCIDEgoToDefinition call PSCIDEgoToDefinition()
function! PSCIDEgoToDefinition()
  let identifier = s:GetWordUnderCursor()
  call s:log('PSCIDEgoToDefinition identifier: ' . identifier, 3)

  let currentModule = s:ExtractModule()
  call s:log('PSCIDEgoToDefinition currentModule: ' . currentModule, 3)

  let resp = s:callPscIde({'command': 'type', 'params': {'search': identifier, 'filters': []}, 'currentModule': currentModule}, 'Failed to get location info for: ' . identifier, 0)

  if type(resp) == type({}) && resp.resultType ==# "success" && len(resp.result) == 1
      call s:goToDefinition(resp.result[0].definedAt)
  endif

  if type(resp) == type({}) && resp.resultType ==# "success" && len(resp.result) > 1
    let choices = copy(resp.result)
    call map (choices, 'v:key. v:val["module"]')
    let choice = confirm("Multiple possibilities for " . identifier , join(choices, "\n"))
    if choice
      call s:goToDefinition(resp.result[choice - 1].definedAt)
    endif
    return
  endif
endfunction

function! s:goToDefinition(definedAt)
  let currentfile = expand("%:p")
  if (currentfile == a:definedAt.name)
    let cur = getpos(".")
    let cur[1] = a:definedAt.start[0]
    call setpos(".", cur)
  else
    let cwd = getcwd()
    call s:log("PSCIDE s:goToDefinition: cwd: " . cwd, 3)

    let lcwd = len(cwd)
    let name = strpart(a:definedAt.name, lcwd + 1) " To strip slash
    call s:log("PSCIDE s:goToDefinition: name: " . name, 3)

    let command = "e +" . a:definedAt.start[0] . " " . name
    call s:log("PSCIDE s:goToDefinition: command: " . command, 3)

    :exe command
  endif
endfunction

function! PSCIDErebuild(stuff)
  let g:psc_ide_suggestions = {}
  let filename = expand("%:p")
  let input = {'command': 'rebuild', 'params': {'file': filename}}

  let resp = s:callPscIde(input, 0, 0)

  if type(resp) == type({}) && has_key(resp, "resultType") 
     \ && has_key (resp, "result") && type(resp.result) == type([])
    if resp.resultType == "error"
      let out = ParsePscJsonOutput(resp.result, [])
    else
      let out = ParsePscJsonOutput([], resp.result)
    endif
    if out.error != ""
      call s:log("PSCIDErebuild: Failed to interpret " . string(resp.result), 0)
    endif

    let g:psc_ide_suggestions = out.suggestions
    return out.llist
  else
    call s:log("PSCIDErebuild: Failed to rebuild " . filename, 0)
    return []
  endif
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

  let command = {'command': 'caseSplit', 'params': {'line': line, 'begin': b, 'end': e, 'annotations': s:jsonFalse(), 'type': t}}

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
  let currentModule = s:ExtractModule()
  call s:log('PSCIDE s:getType currentModule: ' . currentModule, 3)

  let resp = s:callPscIde({'command': 'type', 'params': {'search': a:identifier, 'filters': []}, 'currentModule': currentModule}, 'Failed to get type info for: ' . a:identifier, 0)

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
  let filename = expand("%:p")
  call PSCIDEapplySuggestionPrime(lnr, filename, 0)
endfunction
function! PSCIDEapplySuggestionPrime(lnr, filename, silent)
  "let llist = getloclist(0)

  call s:log('PSCIDEapplySuggestion: lineNr: ' . a:lnr, 3)
  call s:log('PSCIDEapplySuggestion: filename: ' . a:filename, 3)

  let key = a:filename . "|" . string(a:lnr)
  if (has_key(g:psc_ide_suggestions, key))
    let found = g:psc_ide_suggestions[key]
  else
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
  let filename = expand("%:p")
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
    call PSCIDEapplySuggestionPrime(lnr, filename, 1)
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

" VALIDATE -----------------------------------------------------------------------
command! PSCIDEprojectValidate call PSCIDEprojectValidate()
function! PSCIDEprojectValidate()
  let problems = s:projectProblems()

  if len(problems) == 0
    let s:projectvalid = 1
    echom "Your project is setup correctly."
  else
    let s:projectvalid = 0
    echom "Your project is not setup correctly. " . join(problems)
  endif
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
set omnifunc=PSCIDEomni

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

    let currentModule = s:ExtractModule()
    call s:log('PSCIDEOmni currentModule: ' . currentModule, 3)

    let resp = s:callPscIde({'command': 'complete', 'params': {'filters': [s:prefixFilter(str)], 'matcher': s:flexMatcher(str), 'currentModule': currentModule}}, 'Failed to get completions for: '. str, 0)

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
          let e = {'word': entry['identifier'], 'menu': s:StripNewlines(entry['type']), 'info': entry['module'], 'dup': 0}
          let existing = s:findInListBy(result, 'word', e['word'])

          if existing != {}
            let e['menu'] = e['menu'] . ' (' . e['info'] . ')'
            let e['dup'] = 1
            if existing['dup'] == 0
              let existing['menu'] = existing['menu'] . ' (' . existing['info'] . ')'
              let existing['dup'] = 1
            endif
          endif

          call add(result, e)
        endif
      endfor
    endif
    return result
  endif
endfunction

function! s:findInListBy(list, key, str)
  let i = 0
  let l = len(a:list)
  let found = {}
  
  while found == {} && i < l
    if a:list[i][a:key] == a:str
      let found = a:list[i]
    endif
    let i = i + 1
  endwhile

  return found
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
function! s:callPscIde(input, errorm, isRetry)
  call s:log("callPscIde: start: Executing command: " . string(a:input), 3)

  if s:projectvalid == 0
    call PSCIDEprojectValidate()
  endif

  if s:pscidestarted == 0

    let expectedCWD = s:findFileRecur('bower.json')
    let cwdcommand = {'command': 'cwd'}

    call s:log("callPscIde: No server found, looking for external server", 1)
    let cwdresp = s:mysystem("psc-ide-client -p " . g:psc_ide_server_port, s:jsonEncode(cwdcommand))
    call s:log("callPscIde: Raw response of trying to reach external server: " . cwdresp, 1)
    let cwdrespDecoded = PscIdeDecodeJson(s:StripNewlines(cwdresp))
    call s:log("callPscIde: Decoded response of trying to reach external server: " 
                \ . string(cwdrespDecoded), 1)

    if type(cwdrespDecoded) == type({}) && cwdrespDecoded.resultType ==# 'success'
      call s:log("callPscIde: Found external server with cwd: " . string(cwdrespDecoded.result), 1)
      call s:log("callPscIde: Expecting CWD: " . expectedCWD, 1)

      if expectedCWD != cwdrespDecoded.result
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
    let cwdresp2 = s:mysystem("psc-ide-client -p " . g:psc_ide_server_port, s:jsonEncode(cwdcommand))
    call s:log("callPscIde: Raw response of trying to reach server again: " . cwdresp2, 1)
    let cwdresp2Decoded = PscIdeDecodeJson(s:StripNewlines(cwdresp2))
    call s:log("callPscIde: Decoded response of trying to reach server again: " 
               \ . string(cwdresp2Decoded), 1)

    if type(cwdresp2Decoded) == type({}) && cwdresp2Decoded.resultType ==# 'success' 
       \ && cwdresp2Decoded.result == expectedCWD
      call s:log("callPscIde: Server successfully contacted! Loading current module.", 1)
      call PSCIDEload(1)
    else
      call s:log("callPscIde: Server still can't be contacted, aborting...", 1)
      return
    endif
  endif

  let enc = s:jsonEncode(a:input)
  let resp = s:mysystem("psc-ide-client -p " . g:psc_ide_server_port, enc)
  call s:log("callPscIde: Raw response: " . resp, 3)

  if resp =~? "connection refused"  "TODO: This check is probably not crossplatform
    let s:pscidestarted = 0
    let s:pscideexternal = 0

    if a:isRetry
      call s:log("callPscIde: Error: Failed to contact server", 0)
    endif
    if !a:isRetry
      " Seems saving often causes psc-ide-server to crash. Haven't been able
      " to figure out why. It doesn't crash when I run it externally...
      " retrying is then the next best thing
      return s:callPscIde(a:input, a:errorm, 1) " Keeping track of retries so we only retry once
    endif
  endif

  let decoded = PscIdeDecodeJson(s:CleanEnd(s:StripNewlines(resp)))
  call s:log("callPscIde: Decoded response: " . string(decoded), 3)

  if (type(decoded) != type({}) || decoded['resultType'] !=# 'success') 
      \ && type(a:errorm) == type("")
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
"augroup PscIdeAutoLoad
  "au!
  "autocmd BufEnter *.purs call s:AutoLoad()
  "autocmd BufWritePost *.purs call s:AutoLoad()
"augroup END
"function! s:AutoLoad()
  "if s:pscidestarted == 1
    "call PSCIDEload(1)
  "endif
"endfunction

" Automatically close the server when leaving vim
augroup PscideShutDown
  au!
  autocmd VimLeavePre * call s:Shutdown()
augroup END
function! s:Shutdown()
  silent PSCIDEend
endfunction

" " Automatic import after completion
" function! s:completeDone(item)
"   if g:psc_ide_auto_imports == 0
"     return
"   endif
"   if (type(a:item) == type({}) 
"         \ && has_key(a:item, 'word') && type(a:item.word) == type("") 
"         \ && has_key(a:item, 'info')) && type(a:item.info) == type("")
"     call s:importIdentifier(a:item.word, a:item.info)
"   endif
" endfunction
" augroup PscideAfterCompletion
"   autocmd CompleteDone * call s:completeDone(v:completed_item)
" augroup END





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

" Parse Errors & Suggestions ------------------------------------------
" Returns { error :: String, 
"           llist :: Array (String in errorformat), 
"           suggestions :: StrMap { startLine :: Int,
"                                  startColumn :: Int,
"                                  endLine :: Int,
"                                  endColumn :: Int,
"                                  filename :: String,
"                                  replacement :: String } }
" Key of suggestions = <filename>|<linenr>
function! ParsePscJsonOutput(errors, warnings)
  let out = []
  let suggestions = {}

  for e in a:warnings
    try
      call s:addEntry(out, suggestions, 0, e)
    catch /\m^Vim\%((\a\+)\)\=:E716/
      return {'error': 'ParsePscJsonOutput: unrecognized warning format', 
            \ 'llist': [], 
            \ 'suggestions': []}
    endtry
  endfor
  for e in a:errors
    try
      call s:addEntry(out, suggestions, 1, e)
    catch /\m^Vim\%((\a\+)\)\=:E716/
      return {'error': 'ParsePscJsonOutput: unrecognized error format', 
            \ 'llist': [], 
            \ 'suggestions': []}
    endtry
  endfor

  return {'error': "", 'llist': out, 'suggestions': suggestions}
endfunction

function! s:addEntry(out, suggestions, err, e)
  let hasSuggestion = exists("a:e.suggestion") && type(a:e.suggestion) == type({}) &&
                    \ exists("a:e.position") && type(a:e.position) == type({})
  let isError = a:err == 1
  let letter = isError ? (hasSuggestion ? 'F' : 'E') : (hasSuggestion ? 'V' : 'W')
  let startL = (exists("a:e.position") && type(a:e.position) == type({}))
               \ ? a:e.position.startLine : 1
  let startC = (exists("a:e.position") && type(a:e.position) == type({}))
               \ ? a:e.position.startColumn : 1
  let msg = join([letter, 
                \ a:e.filename, 
                \ startL,
                \ startC,
                \ s:cleanupMessage(a:e.message)], ":")

  call add(a:out, msg)

  if hasSuggestion
    call s:addSuggestion(a:suggestions, a:e)
  endif
endfunction

function! s:addSuggestion(suggestions, e)
  let sugg = {'startLine':   a:e['position']['startLine'], 
             \'startColumn': a:e['position']['startColumn'], 
             \'endLine':     a:e['position']['endLine'], 
             \'endColumn':   a:e['position']['endColumn'], 
             \'filename':    a:e['filename'],
             \'replacement': a:e['suggestion']['replacement']}

   let a:suggestions[a:e.filename . "|" . string(a:e.position.startLine)] = sugg
endfunction

function! s:cleanupMessage(str)
    let transformations = [ ['\s*\n\+\s*', ' '], ['(\s', '('], ['\s)', ')'], ['\s\,', ','] ]
    let out = a:str
    for t in transformations
        let out = substitute(out, t[0], t[1], 'g')
    endfor
    return out
endfunction

function! PscIdeDecodeJson(json) abort
  if a:json ==# ''
      return []
  endif

  if substitute(a:json, '\v\"%(\\.|[^"\\])*\"|true|false|null|[+-]?\d+%(\.\d+%([Ee][+-]?\d+)?)?', '', 'g') !~# "[^,:{}[\\] \t]"
      " JSON artifacts
      let true = 1
      let false = 0
      let null = ''

      try
          let object = eval(a:json)
      catch
          " malformed JSON
          let object = ''
      endtry
  else
      let object = ''
  endif

  return object
endfunction

function! s:mysystem(a, b)
  return system(a:a, a:b . "\n")
endfunction
