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

if !exists('g:psc_ide_check_output_dir')
  let g:psc_ide_check_output_dir = 1
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

let s:psc_ide_server = v:none
"Looks for bower.json, assumes that's the root directory, starts
"`purs ide server` in the background
"Returns Nothing
command! -buffer PSCIDEstart call PSCIDEstart(0)
function! PSCIDEstart(silent)
  if s:pscidestarted == 1 
    return
  endif
  let loglevel = a:silent == 1 ? 1 : 0

  let dir = s:findRoot()
  call s:log("PSCIDEstart: cwd " . dir, 3)

  if empty(dir)
    echom "No psc-package.json or bower.json found, couldn't start `purs ide server`"
    return
  endif

  let command = [ 
	\ "purs", "ide", "server",
	\ "-p", g:psc_ide_server_port,
	\ "-d", dir,
	\ "src/**/*.purs",
	\ "bower_components/**/*.purs",
	\ ]

  exe "lcd" dir
  let s:psc_ide_server = job_start(
	\ command,
	\ { "stoponexit": "term"
	\ , "err_mode": "raw"
	\ , "err_cb": { ch, msg -> s:log("purs ide server error: " . string(msg), 0) }
	\ , "in_io": "null"
	\ , "out_io": "null"
	\ }
	\ )
  lcd -

  call s:log("PSCIDEstart: Sleeping for 100ms so server can start up", 1)
  sleep 100m
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


" Display choices from a list of dicts for the user to select from with
" alphanumerals as shortcuts
function! s:pickOption(message, options, labelKey)
  let displayOptions = copy(a:options)
  call map(displayOptions, '(v:key > 9 ? nr2char(v:key + 55) : v:key) . " " . v:val[a:labelKey]')
  let choice = confirm(a:message, join(displayOptions, "\n"))
  if choice
    return {'picked': v:true, 'option': a:options[choice - 1]}
  else
    return {'picked': v:false, 'option': v:none}
  endif
endfunction

" Find root folder ----------------------------------------------------
function! s:findRoot()
  let pscPackage = findfile("psc-package.json", fnameescape(expand("%:p:h")).";")
  if !empty(pscPackage)
    return fnamemodify(pscPackage, ":h:p")
  else
    let bower = findfile("bower.json", fnameescape(expand("%:p:h")).";")
    if !empty(bower)
      return fnamemodify(bower, ":h:p")
    else
      return ""
    endif
  endfor
endfunction

" END ------------------------------------------------------------------------
" Tell the `purs ide server` to quit
command! -buffer PSCIDEend call PSCIDEend()
function! PSCIDEend()
  if s:pscideexternal == 1
    return
  endif
  let filename = tempname()
  call writefile([json_encode({'command': 'quit'})], filename)
  return job_start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "exit_cb": {job, status -> s:PSCIDEendCallback() }
	\ , "err_cb": {err -> s:log("PSCIDEend error: " . string(err), 0)}
	\ , "in_io": "file"
	\ , "in_name": filename
	\ })
endfunction

function! s:PSCIDEendCallback() 
  let s:pscidestarted = 0
  let s:projectvalid = 0
endfunction

function! s:projectProblems()
  let rootdir = s:findRoot()
  let problems = []

  if empty(rootdir)
    call add(problems, "Your project is missing a bower.json or psc-package.json file")
  elseif g:psc_ide_check_output_dir == 1
    let outputcontent = s:globpath(rootdir, "output/*")
    if len(outputcontent) == 0
      call add(problems, "Your project's /output directory is empty.  You should run `pulp build` to compile your project.")
    endif
  endif

  return problems
endfunction

" LOAD -----------------------------------------------------------------------
" Load module of current buffer + its dependencies into `purs ide server`
command! -buffer PSCIDEload call PSCIDEload(0)
function! PSCIDEload(silent)
  let loglevel = a:silent == 1 ? 1 : 0

  let input = {'command': 'load'}

  call s:callPscIde(
	\ input,
	\ "Failed to load",
	\ 0,
	\ {msg -> s:PSCIDEloadCallback(loglevel, msg)}
	\ )
endfunction

function! s:PSCIDEloadCallback(loglevel, resp)
  if type(a:resp) == type({}) && a:resp['resultType'] ==# "success"
    call s:log("PSCIDEload: Successfully loaded modules: " . string(a:resp["result"]), a:loglevel)
  else
    call s:log("PSCIDEload: Failed to load. Error.", a:loglevel)
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
command! -buffer PSCIDEimportIdentifier call PSCIDEimportIdentifier()
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

  call writefile(getline(1, '$'), s:tempfile)

  let input = { 
        \ 'command': 'import' ,
        \ 'params': {
        \   'file': s:tempfile, 
        \   'importCommand': {
        \     'importCommand': 'addImport',
        \     'identifier': ident
        \   } } }

  if a:module != ""
    let input.params.filters = [{'filter': 'modules', 'params': {'modules': [a:module]}}]
  endif

  call s:callPscIde(
	\ input,
	\ "Failed to import identifier " . ident, 
	\ 0,
	\ {resp -> s:PSCIDEimportIdentifierCallback(ident, a:id, a:module, resp)}
	\ )
endfunction

function! s:PSCIDEimportIdentifierCallback(ident, id, module, resp) 
  "multiple possibilities
  call s:log("s:PSCIDEimportIdentifierCallback", 3)
  if type(a:resp) == type({}) && a:resp.resultType ==# "success" && type(a:resp.result[0]) == type({})
    " filter results
    let results = []
    for res in a:resp.result
      if empty(filter(copy(results), { idx, val -> val.module == res.module }))
	call add(results, res)
      endif
    endfor
    if (len(results) == 1)
      let choice = { option: results[0], picked: v:true }
    else
      let choice = s:pickOption("Multiple possibilities to import " . a:ident, results, "module")
    endif
    if choice.picked == v:true
      call s:importIdentifier(a:ident, choice.option.module)
    endif
    return
  endif

  if type(a:resp) == type({}) && a:resp['resultType'] ==# "success"
    let newlines = a:resp.result

    let linesdiff = len(newlines) - line("$")
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
    let view = winsaveview()
    call setline(1, filter(copy(newlines), { idx -> idx < nrOfLinesToReplace + nrOfLinesToAppend }))

    if (nrOfLinesToDelete > 0)
      let view["lnum"] -= nrOfLinesToDelete
      exe 'silent ' . (nrOfLinesToReplace + 1) . "," . (nrOfLinesToReplace + nrOfLinesToDelete) . "d_|0"
    endif
    if (nrOfLinesToAppend > 0)
      let linesToAppend = filter(copy(newlines), { idx -> idx > nrOfLinesToReplace && idx <= nrOfLinesToReplace + nrOfLinesToAppend  })
      let view["lnum"] += nrOfLinesToAppend
      call append(line("."), linesToAppend)
    endif
    call winrestview(view)

    call s:log("PSCIDEimportIdentifier: Succesfully imported identifier: " . a:module . " ".a:id, 3)
  else
    call s:log("PSCIDEimportIdentifier: Failed to import identifier " . a:ident . ". Error: " . string(a:resp["result"]), 0)
  endif
endfunction

command! -buffer PSCIDEgoToDefinition call PSCIDEgoToDefinition()
function! PSCIDEgoToDefinition()
  let identifier = s:GetWordUnderCursor()
  call s:log('PSCIDEgoToDefinition identifier: ' . identifier, 3)

  let currentModule = s:ExtractModule()
  call s:log('PSCIDEgoToDefinition currentModule: ' . currentModule, 3)

  call s:callPscIde(
	\   {'command': 'type', 'params': {'search': identifier, 'filters': []}, 'currentModule': currentModule},
	\ 'Failed to get location info for: ' . identifier,
	\ 0,
	\ { resp -> s:PSCIDEgoToDefinitionCallback(identifier, resp) }
	\ )
endfunction

function! s:PSCIDEgoToDefinitionCallback(identifier, resp)
  call s:log("s:PSCIDEgoToDefinitionCallback", 3)
  let results = []
  for res in a:resp.result
    if empty(filter(copy(results), { idx, val -> 
	  \    type(val.definedAt) == v:t_dict
	  \ && type(res.definedAt) != v:t_dict
	  \ && val.definedAt.name == res.definedAt.name
	  \ && val.definedAt.start[0] == res.definedAt.start[0]
	  \ && val.definedAt.start[1] == res.definedAt.start[1]}))
      call add(results, res)
    endif
  endfor
  if type(a:resp) == v:t_dict && a:resp.resultType ==# "success"
    if len(results) > 1
      let choice = s:pickOption("Multiple possibilities for " . a:identifier, results, "module")
    elseif len(results) == 1
      let choice = {"picked": v:true, "option": results[0]}
    else
      let choice = {"picked": v:false, "option": v:none}
    endif
    if choice.picked && type(choice.option.definedAt) == type({})
      call s:goToDefinition(choice.option.definedAt)
    elseif type(choice.option) == v:t_dict
      echom "PSCIDE: No location information found for: " . a:identifier . " in module " . choice.option.module
    else
      echom "PSCIDE: No location information found for: " . a:identifier
    endif
  else
    echom "PSCIDE: No location information found for: " . a:identifier
  endif
endfunction

function! s:goToDefinition(definedAt)
  let currentfile = expand("%:p")
  let fname = a:definedAt.name
  let cwd = s:findRoot()
  let fname = fnameescape(findfile(fname, cwd))
  if (currentfile == fname)
    " set ' mark at the current position
    m'
    call cursor(a:definedAt.start[0], a:definedAt.start[1])
  else
    call s:log("PSCIDE s:goToDefinition: fname: " . fname, 3)

    let command = "e +" . a:definedAt.start[0] . " " . fname
    call s:log("PSCIDE s:goToDefinition: command: " . command, 3)
    exe command
    exe "normal " . a:definedAt.start[1] . "|"
  endif
endfunction

function! PSCIDErebuild(async, ...)
  let g:psc_ide_suggestions = {}
  let filename = expand("%:p")
  let input = {'command': 'rebuild', 'params': {'file': filename}}

  if a:0 > 0 && type(a:1) == v:t_func
    let CallBack = a:1
  else
    let CallBack = {resp -> resp}
  endif

  if a:async
    call s:callPscIde(
	  \ input,
	  \ 0,
	  \ 0,
	  \ { msg -> CallBack(s:PSCIDErebuildCallback(filename, msg)) }
	  \ )
  else
    let resp = s:PSCIDErebuildCallback(
	      \ filename,
	      \ s:callPscIdeSync(input, 0, 0),
	      \ )
    return CallBack(resp)
  endif
endfunction

function! s:PSCIDErebuildCallback(filename, resp) 
  if type(a:resp) == type({}) && has_key(a:resp, "resultType") 
     \ && has_key (a:resp, "result") && type(a:resp.result) == type([])
    if a:resp.resultType == "error"
      let out = ParsePscJsonOutput(a:resp.result, [])
    else
      let out = ParsePscJsonOutput([], a:resp.result)
    endif
    if out.error != ""
      call s:log("PSCIDErebuild: Failed to interpret " . string(a:resp.result), 0)
    endif

    let g:psc_ide_suggestions = out.suggestions
    return out.llist
  else
    call s:log("PSCIDErebuild: Failed to rebuild " . a:filename, 0)
    return []
  endif
endfunction

" Add type annotation
command! -buffer PSCIDEaddTypeAnnotation call PSCIDEaddTypeAnnotation()
function! PSCIDEaddTypeAnnotation()
  let identifier = matchstr(getline(line(".")), '^\s*\zs\k\+\ze')

  call s:getType(
	\ identifier,
	\ { resp -> s:PSCIDEaddTypeAnnotationCallback(identifier, resp) }
	\ )
endfunction

function! s:PSCIDEaddTypeAnnotationCallback(identifier, resp)
  if type(a:resp) == v:t_dict && a:resp["resultType"] ==# 'success' && !empty(a:resp["result"])
    let result = a:resp["result"]
    let lnr = line(".")
    let indent = matchstr(getline(lnr), '^\s*\ze')
    call append(lnr - 1, indent . s:StripNewlines(result[0]['identifier']) . ' :: ' . s:StripNewlines(result[0]["type"]))
  else
    echom "PSC-IDE: No type information found for " . a:identifier
  endif
endfunction

" CWD ------------------------------------------------------------------------
" Get current working directory of `pure ide server`
command! -buffer PSCIDEcwd call PSCIDEcwd()
function! PSCIDEcwd()
  call s:callPscIde(
	\ {'command': 'cwd'},
	\ "Failed to get current working directory", 
	\ 0,
	\ function("s:PSCIDEcwdCallback")
	\ )
endfunction

function! s:PSCIDEcwdCallback(resp)
  if type(a:resp) == type({}) && a:resp['resultType'] ==# 'success'
    echom "PSC-IDE: Current working directory: " . a:resp["result"]
  endif
endfunction

" ADDCLAUSE
" Makes template function implementation from signature
command! -buffer PSCIDEaddClause call PSCIDEaddClause()
function! PSCIDEaddClause()
  let lnr = line(".")
  let line = getline(lnr)

  let command = {'command': 'addClause', 'params': {'line': line, 'annotations': v:false}}

  call s:callPscIde(
	\ command,
	\ "Failed to add clause",
	\ 0,
	\ { resp -> s:PSCIDEaddClauseCallback(lnr, resp) }
	\ )
endfunction

function! s:PSCIDEaddClauseCallback(lnr, resp)
  if type(a:resp) == type({}) && a:resp['resultType'] ==# 'success' && type(a:resp.result) == type([])     
    call s:log('PSCIDEaddClause results: ' . string(a:resp.result), 3)
    call append(a:lnr, a:resp.result)
    normal dd
  endif
endfunction

" CASESPLIT
" Hover cursor over variable in function declaration -> pattern match on all
" different cases of the variable
command! -buffer PSCIDEcaseSplit call PSCIDEcaseSplit()
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

  let command = {
	\ 'command': 'caseSplit',
	\ 'params': { 'line': line, 'begin': b, 'end': e, 'annotations': v:false, 'type': t}
	\ }

  call s:callPscIde(
	\ command,
	\ 'Failed to split case for: ' . word,
	\ 0,
	\ { resp -> s:PSCIDEcaseSplitCallback(lnr, resp) }
	\ )
endfunction

function! s:PSCIDEcaseSplitCallback(lnr, resp)
  if type(a:resp) == type({}) && a:resp['resultType'] ==# 'success' && type(a:resp.result) == type([])     
    call s:log('PSCIDEcaseSplit results: ' . string(a:resp.result), 3)
    call append(a:lnr, a:resp.result)
    normal dd
  endif
endfunction

" TYPE -----------------------------------------------------------------------
" Get type of word under cursor
command! -buffer PSCIDEtype call PSCIDEtype()
function! PSCIDEtype()
  let identifier = s:GetWordUnderCursor()

  call s:getType(
	\ identifier,
	\ { resp -> s:PSCIDEtypeCallback(identifier, resp.result) }
	\ )
endfunction

function! s:PSCIDEtypeCallback(identifier, result)
  if type(a:result) == type([])
    for e in a:result
      echom s:formattype(e)
    endfor
  else
    echom "PSC-IDE: No type information found for " . a:identifier
  endif
endfunction

" LISTIMPORTS -----------------------------------------------------------------------
" List the modules imported by the current module
command! PSCIDElistImports call PSCIDElistImports()
function! PSCIDElistImports()
  let currentModule = s:ExtractModule()
  call s:log('PSCIDElistImports ' . currentModule, 3)
  let imports =  s:ListImports(currentModule)
  for import in imports
    call s:EchoImport(import)
  endfor
  if (len(imports) == 0)
    echom "PSC-IDE: No import information found for " . currentModule
  endif

endfunction

function! s:EchoImport(import)
  echohl Identifier
  echon a:import["module"]
  echohl Normal
  if has_key(a:import, "identifiers")
    echon " ("
    let len = len(a:import["identifiers"])
    let idx = 0
    for ident in a:import["identifiers"]
      echohl Identifier
      echon ident 
      echohl Normal
      if (idx < len - 1)
	echon ", "
      else
	echon ")"
      endif
      let idx += 1
    endfor
  endif
  if has_key(a:import, "qualifier")
    echohl Keyword
    echon " as "
    echohl Identifier
    echon a:import["qualifier"]
    echohl Normal
  endif
  echon "\n"
endfunction

function! s:ListImports(module)
  let filename = expand("%:p")
  call s:log('PSCIDE s:ListImports ' . a:module . ' in file ' . filename, 1)
  let resp = s:callPscIdeSync(
	\ {'command': 'list', 'params': {'type': 'import', 'file': filename}},
	\ 'Failed to get imports for: ' . a:module,
	\ 0
	\ )
  call s:log("PSCIDE s:ListImports result: " . string(resp), 3)
  " Only need module names right now, so pluck just those.
  if type(resp) == type({}) && resp['resultType'] ==# 'success'
    " psc-ide >=0.11 returns imports on 'imports' property.
    return type(resp['result']) == type([]) ? resp['result'] : resp['result']['imports']
    endif
  endif
endfunction

function! s:getType(identifier, cb)
  let currentModule = s:ExtractModule()
  let importedModules = add(map(s:ListImports(currentModule), {key, val -> val["module"]}), currentModule)
  call s:log('PSCIDE s:getType currentModule: ' . currentModule, 3)

  call s:callPscIde(
	\ {'command': 'type', 'params': {'search': a:identifier, 'filters': [{'filter': 'modules' , 'params': {'modules': importedModules } }], 'currentModule': currentModule}},
	\  'Failed to get type info for: ' . a:identifier,
	\ 0,
	\ {resp -> a:cb(resp)}
	\ )
endfunction

function! s:formattype(record)
  return s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['identifier']) . ' ∷ ' . s:StripNewlines(a:record['type']))
endfunction

" APPLYSUGGESTION ------------------------------------------------------
" Apply suggestion in loclist to buffer --------------------------------
command! -buffer PSCIDEapplySuggestion call PSCIDEapplySuggestion()
function! PSCIDEapplySuggestion()
  let lnr = line(".")
  let filename = expand("%:p")
  call PSCIDEapplySuggestionPrime(lnr, filename, 0)
endfunction

function! PSCIDEapplySuggestionPrime(lnr, filename, silent)
  let dir = s:findRoot()
  let key = fnamemodify(a:filename, ':s?'.dir.'/??') . "|" . string(a:lnr)

  call s:log('PSCIDEapplySuggestion: lineNr: ' . a:lnr . "filename: " . a:filename . " key: " . key, 3)

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
command! -buffer PSCIDEremoveImportQualifications call PSCIDEremoveImportQualifications()
function! PSCIDEremoveImportQualifications()
  let captureregex = "import\\s\\(\\S\\+\\)\\s*(.*)"
  let replace = "import \\1"
  let command = "silent %s:" . captureregex . ":" . replace . ":g|norm!``"
  call s:log('Executing PSCIDEremoveImportQualifications command: ' . command, 3)
  :exe command
endfunction

" Add all import qualifications
command! -buffer PSCIDEaddImportQualifications call PSCIDEaddImportQualifications()
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
command! -buffer PSCIDEpursuit call PSCIDEpursuit()
function! PSCIDEpursuit()
  let identifier = s:GetWordUnderCursor()

  call s:callPscIde(
	\ {'command': 'pursuit', 'params': {'query': identifier, 'type': "completion"}},
	\ 'Failed to get pursuit info for: ' . identifier,
	\ 0,
	\ { resp -> s:PSCIDEpursuitCallback(resp) }
	\ )
endfunction

function! s:PSCIDEpuresuitCallback(resp)
  if type(a:resp) == type({}) && a:resp['resultType'] ==# 'success'
    if len(a:resp["result"]) > 0
      for e in a:resp["result"]
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
command! -buffer PSCIDEprojectValidate call PSCIDEprojectValidate()
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
command! -buffer PSCIDElist call PSCIDElist()
function! PSCIDElist()
  let resp = s:callPscIdeSync(
	\ {'command': 'list', 'params': {'type': 'loadedModules'}},
	\ 'Failed to get loaded modules',
	\ 0
	\ )
  call s:PSCIDElistCallback(resp)
endfunction

function! s:PSCIDElistCallback(resp)
  if type(a:resp) == type({}) && a:resp['resultType'] ==# 'success'
    if len(a:resp["result"]) > 0
      for m in a:resp["result"]
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

    let resp = s:callPscIdeSync(
	  \ {'command': 'complete', 'params': {'filters': [s:prefixFilter(str)], 'matcher': s:flexMatcher(str), 'currentModule': currentModule}},
	  \ 'Failed to get completions for: '. str,
	  \ 0)

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
function! s:callPscIde(input, errorm, isRetry, cb)
  call s:log("callPscIde: start: Executing command: " . string(a:input), 3)

  if s:projectvalid == 0
    call PSCIDEprojectValidate()
  endif

  if s:pscidestarted == 0

    let expectedCWD = fnamemodify(s:findRoot(), ":p:h")
    call s:log("callPscIde: cwd " . expectedCWD, 3)
    let cwdcommand = {'command': 'cwd'}
    let tempfile = tempname()
    call writefile([json_encode(cwdcommand)], tempfile)

    call s:log("callPscIde: No server found, looking for external server", 1)
    call job_start(
	  \ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	  \ { "out_cb": {ch, msg -> s:PscIdeStartCallback(a:input, a:errorm, a:cb, cwdcommand, msg)}
	  \ , "err_cb": {ch, err -> s:log("s:callPscIde error: " . string(err), 3)}
	  \ , "in_io": "file"
	  \ , "in_name": tempfile
	  \ })
    call delete(tempfile)
    return
  endif

  let enc = json_encode(a:input)
  let tempfile = tempname()
  call writefile([enc], tempfile, "b")
  call s:log("callPscIde: purs ide client: " . enc, 3)
  call job_start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "out_cb": {ch, msg -> a:cb(s:PscIdeCallback(a:input, a:errorm, a:isRetry, a:cb, msg))}
	\ , "in_io": "file"
	\ , "in_name": tempfile
	\ , "err_cb": {ch, err -> s:log("s:callPscIde error: " . string(err), 3)}
	\ })
  call delete(tempfile)
endfunction

function! s:callPscIdeSync(input, errorm, isRetry)
  call s:log("callPscIde: start: Executing command: " . string(a:input), 3)

  if s:projectvalid == 0
    call PSCIDEprojectValidate()
  endif

  if s:pscidestarted == 0

    let expectedCWD = s:findRoot()
    let cwdcommand = {'command': 'cwd'}

    call s:log("callPscIde: No server found, looking for external server", 1)
    let cwdresp = s:mysystem("purs ide client -p " . g:psc_ide_server_port, json_encode(cwdcommand))
    return s:PscIdeStartCallback(a:input, a:errorm, 0, cwdcommand, cwdresp)
  endif

  call s:log("callPscIde: Trying to reach server again", 1)
  let enc = json_encode(a:input)
  let resp = s:mysystem("purs ide client -p " . g:psc_ide_server_port, enc)
  return s:PscIdeCallback(a:input, a:errorm, a:isRetry, 0, resp)
endfunction

" UTILITY FUNCTIONS ----------------------------------------------------------
function! s:PscIdeStartCallback(input, errorm, cb, cwdcommand, cwdresp)
  let expectedCWD = s:findRoot()
  try
    let cwdrespDecoded = json_decode(a:cwdresp)
  catch /.*/
    let cwdrespDecoded = {"resultType": "failed", "error": a:cwdresp}
  endtry

  call s:log("s:PscIdeStartCallback: Decoded response of trying to reach external server: " 
	      \ . string(cwdrespDecoded), 1)

  if type(cwdrespDecoded) == type({}) && cwdrespDecoded.resultType ==# 'success'
    call s:log("s:PscIdeStartCallback: Found external server with cwd: " . string(cwdrespDecoded.result), 1)
    call s:log("s:PscIdeStartCallback: Expecting CWD: " . expectedCWD, 1)

    if expectedCWD != cwdrespDecoded.result
      call s:log("s:PscIdeStartCallback: External server on incorrect CWD, closing", 1)
      call PSCIDEend()
      call s:log("s:PscIdeStartCallback: Starting new server", 1)
      call PSCIDEstart(1)
    else
      call s:log("s:PscIdeStartCallback: External server CWD matches with what we need", 1)
      let s:pscidestarted = 1
      let s:pscideexternal = 1
    endif
  else
    call s:log("s:PscIdeStartCallback: No external server found, starting new server", 1)
    call PSCIDEstart(1)
  endif
  call s:log("s:PscIdeStartCallback: Trying to reach server again", 1)
  if (type(a:cb) == type(0) && !a:cb)
    let cwdresp = s:mysystem(
	  \ "purs ide client -p" . g:psc_ide_server_port,
	  \ json_encode(a:cwdcommand)
	  \ )
    return s:PscIdeRetryCallback(a:input, a:errorm, 0, expectedCWD, cwdresp)
  endif
  let tempfile = tempname()
  call writefile([json_encode(a:cwdcommand)], tempfile)
  call job_start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "out_cb": { ch, resp -> s:PscIdeRetryCallback(a:input, a:errorm, a:cb, expectedCWD, resp) }
	\ , "in_io": "file"
	\ , "in_name": tempfile
	\ , "err_cb": { ch, err -> s:log("s:PscIdeStartCallback error: " . err, 3) }
	\ })
  call delete(tempfile)
endfunction

function! s:PscIdeRetryCallback(input, errorm, cb, expectedCWD, cwdresp2)
  call s:log("s:PscIdeRetryCallback: Raw response of trying to reach server again: " . a:cwdresp2, 1)
  try
    let cwdresp2Decoded = json_decode(a:cwdresp2)
  catch /.*/
    let cwdresp2Decoded = {"resultType": "failed", "error": a:cwdresp2}
  endtry
  call s:log("s:PscIdeRetryCallback: Decoded response of trying to reach server again: " 
	     \ . string(cwdresp2Decoded), 1)

  if type(cwdresp2Decoded) == type({}) && cwdresp2Decoded.resultType ==# 'success' 
     \ && cwdresp2Decoded.result == a:expectedCWD
    call s:log("s:PscIdeRetryCallback: Server successfully contacted! Loading current module.", 1)
    call PSCIDEload(1)
  else
    call s:log("s:PscIdeRetryCallback: Server still can't be contacted, aborting...", 1)
    return
  endif

  let enc = json_encode(a:input)
  if (type(a:cb) == type(0))
    let resp = s:mysystem(
	  \ "purs ide client -p" . g:psc_ide_server_port,
	  \ enc
	  \ )
    return s:PscIdeCallback(a:input, a:errorm, 1, 0, resp)
  endif

  if (type(a:cb) == type(0) && !a:cb)
    let resp = s:mysystem(
	  \ "purs ide client -p" . g:psc_ide_server_port
	  \ enc
	  \ )
    return s:PscIdeCallback(a:input, a:errorm, 1, 0, resp)
  endif
  let tempfile = tempname()
  call writefile([enc], tempfile, "b")
  call s:log("callPscIde: purs ide client: " . enc, 3)
  call job_start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "out_cb": {ch, resp -> a:cb(s:PscIdeCallback(a:input, a:errorm, 1, a:cb, resp))}
	\ , "in_io": "file"
	\ , "in_name": tempfile
	\ , "err_cb": {ch, err -> s:log("s:PscIdeRetryCallback error: " . err, 3)}
	\ })
  call delete(tempfile)
endfunction

function! s:PscIdeCallback(input, errorm, isRetry, cb, resp)
  call s:log("s:PscIdeCallback: Raw response: " . a:resp, 3)

  try
    let decoded = json_decode(a:resp)
  catch /.*/
    let s:pscidestarted = 0
    let s:pscideexternal = 0

    if a:isRetry
      call s:log("s:PscIdeCallback: Error: Failed to contact server", 0)
    endif
    if !a:isRetry
      " Seems saving often causes `purs ide server` to crash. Haven't been able
      " to figure out why. It doesn't crash when I run it externally...
      " retrying is then the next best thing
      return s:callPscIde(a:input, a:errorm, 1, a:cb) " Keeping track of retries so we only retry once
    endif
  endtry

  call s:log("s:PscIdeCallback: Decoded response: " . string(decoded), 3)

  if (type(decoded) != type({}) || decoded['resultType'] !=# 'success') 
      \ && type(a:errorm) == type("")
    call s:log("s:PscIdeCallback: Error: " . a:errorm, 0)
  endif
  return decoded
endfunction

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
function! PSCIDEerrors(llist)
  let qflist = []
  for e in a:llist
    let eparts = split(e, ":")
    let bufnr = bufnr(eparts[1])
    if bufnr != -1
      call add(
	    \   qflist
	    \ , { "bufnr": bufnr(eparts[1])
	    \   , "filename": eparts[1]
	    \   , "lnum": eparts[2]
	    \   , "col": eparts[3]
	    \   , "text": join(filter(eparts, {idx -> idx >= 4}), ":")
	    \   , "type": eparts[0]
	    \   }
	    \ )
    endif
  endfor
  call setqflist(qflist)
endfunction
if g:psc_ide_syntastic_mode == 0
  com! PSCIDErebuild call PSCIDErebuild(1, function("PSCIDEerrors"))
  augroup purescript
    au! BufWritePost *.purs call PSCIDErebuild(1, function("PSCIDEerrors"))
  augroup END
endif

silent! call PSCIDEstart(0)
silent! call PSCIDEload(0)

" PSCIDEerr ------------------------------------------------------------------
fun PSCIDEerr(nr)
  let qf = getqflist()
  if a:nr > 0 && a:nr < len(qf) + 1
    let e = qf[a:nr - 1]
    echo getline(e["lnum"])
    let col = e["col"]
    echon "\n" . repeat(" ", col - 1)
    echohl Error
    echon "^\n\n"
    echohl Normal
    echo e["text"]
  endif
endfun

command! -buffer -count=1 PSCIDEerr call PSCIDEerr(<count>)

" Parse Errors & Suggestions -------------------------------------------------
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
                \ a:e.message], ":")

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

function! s:mysystem(a, b)
  return system(a:a, a:b . "\n")
endfunction
