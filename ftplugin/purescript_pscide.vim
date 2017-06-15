" Inits ----------------------------------------------------------------------
if !exists("b:loaded_psc_ide_vim")
  let b:loaded_psc_ide_vim = v:true
else
  finish
endif

if !exists("g:loaded_psc_ide_vim")
  let g:loaded_psc_ide_vim = v:false
endif

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

if !exists('g:psc_ide_notify')
  let g:psc_ide_notify = v:true
endif

if !exists('g:psc_ide_filter_prelude_modules')
  let g:psc_ide_filter_prelude_modules = v:true
endif

if !exists('g:psc_ide_omnicompletion_filter_modules')
  let g:psc_ide_omnicompletion_filter_modules = v:false
endif

if !exists('g:psc_ide_omnicompletion_sort_by')
  " flex / identifier / module
  let g:psc_ide_omnicompletion_sort_by = "flex"
endif

if !exists("g:psc_ide_omnicompletion_prefix_filter")
  " with this option will let purs ide filter by prefix (this disables flex
  " matching) (tip: use i^xu when searching for a command)
  let g:psc_ide_omnicompletion_prefix_filter = v:true
endif

if !exists("g:psc_ide_prelude")
  let g:psc_ide_prelude = [
    \ "Control.Applicative",
    \ "Control.Apply",
    \ "Control.Bind",
    \ "Control.Category",
    \ "Control.Monad",
    \ "Control.Semigroupoid",
    \ "Data.Boolean",
    \ "Data.BooleanAlgebra",
    \ "Data.Bounded",
    \ "Data.CommutativeRing",
    \ "Data.Eq",
    \ "Data.EuclideanRing",
    \ "Data.Field",
    \ "Data.Function",
    \ "Data.Functor",
    \ "Data.HeytingAlgebra",
    \ "Data.NaturalTransformation",
    \ "Data.Ord",
    \ "Data.Ordering",
    \ "Data.Ring",
    \ "Data.Semigroup",
    \ "Data.Semiring",
    \ "Data.Show",
    \ "Data.Unit",
    \ "Data.Void",
    \ ]
endif

if !exists('g:psc_ide_filter_submodules')
  " this might hide some modules, e.g. React.DOM.Dynamic will be hidden by
  " React.DOM module, you can adjust g:psc_ide_filter_submodules_do_not_hide
  " variable.
  let g:psc_ide_filter_submodules = v:false
endif

if !exists("g:psc_ide_filter_submodules_do_not_hide")
  let g:psc_ide_filter_submodules_do_not_hide = [ "React.DOM.Dynamic" ]
endif

" Adding iskeyword symbols to improve <cword> expansion- ---------------------
" 124 = |
setl omnifunc=PSCIDEomni
setl completefunc=PSCIDEcomplete

" Syntastic initialization ---------------------------------------------------
if exists('g:syntastic_extra_filetypes')
  call add(g:syntastic_extra_filetypes, 'purescript')
else
  let g:syntastic_extra_filetypes = ['purescript']
endif

let g:syntastic_purescript_checkers = ['pscide']

" COMMANDS -------------------------------------------------------------------
com! -buffer PSCIDEend call PSCIDEend()
com! -buffer -bang PSCIDEload call PSCIDEload(0, <q-bang>)
com! -buffer -nargs=* -complete=custom,PSCIDEcompleteIdentifier PSCIDEimportIdentifier call PSCIDEimportIdentifier(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer -nargs=* -complete=custom,PSCIDEcompleteIdenfifier PSCIDEgoToDefinition call PSCIDEgoToDefinition(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer PSCIDEaddTypeAnnotation call PSCIDEaddTypeAnnotation(matchstr(getline(line(".")), '^\s*\zs\k\+\ze'))
com! -buffer PSCIDEcwd call PSCIDEcwd()
com! -buffer PSCIDEaddClause call PSCIDEaddClause()
com! -buffer -nargs=1 PSCIDEcaseSplit call PSCIDEcaseSplit(<q-args>)
com! -buffer -nargs=* -complete=custom,PSCIDEcompleteIdentifier PSCIDEtype call PSCIDEtype(len(<q-args>) ? <q-args> : PSCIDEgetKeyword(), v:true)
com! PSCIDElistImports call PSCIDElistImports()
com! -buffer -bang PSCIDEapplySuggestion call PSCIDEapplySuggestion(<q-bang>)
com! -buffer PSCIDEaddImportQualifications call PSCIDEaddImportQualifications()
com! -buffer -nargs=* PSCIDEpursuit call PSCIDEpursuit(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer PSCIDEprojectValidate call PSCIDEprojectValidate()
com! -buffer PSCIDElist call PSCIDElist()
com! -buffer PSCIDEstart call PSCIDEstart(0)
com! -buffer -nargs=* -complete=custom,PSCIDEcompleteIdentifier PSCIDEsearch call PSCIDEsearch(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer -nargs=* -complete=custom,PSCIDEimportModuleCompletion PSCIDEimportModule call PSCIDEimportModule(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())

" AUTOSTART ------------------------------------------------------------------
fun! s:autoStart()
  if g:psc_ide_syntastic_mode == 0
    com! PSCIDErebuild call PSCIDErebuild(v:true, function("PSCIDEerrors"))
    augroup purescript
      au! BufWritePost *.purs call PSCIDErebuild(v:true, function("PSCIDEerrors"))
      au! BufAdd *.purs call PSCIDErebuild(v:true, function("PSCIDEerrors"))
    augroup END
  endif

  silent! call PSCIDEstart(0)
  silent! call PSCIDEload(0, "")
endfun

" INTERNALS -------------------------------------------------------------------
" execute only once so we do not redefine functions when they are running
if g:loaded_psc_ide_vim
  call s:autoStart()
  finish
endif
let g:loaded_psc_ide_vim = v:true

" START ----------------------------------------------------------------------
let s:psc_ide_server = v:null
"Looks for bower.json, assumes that's the root directory, starts
"`purs ide server` in the background
"Returns Nothing
function! PSCIDEstart(silent)
  if purescript#ide#started()
    return
  endif
  let loglevel = a:silent == 1 ? 1 : 0

  let dir = purescript#ide#utils#findRoot()
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
  call purescript#ide#utils#debug("PSCIDEstart: " . json_encode(command), 3)
  let jobid = async#job#start(
	\ command,
	\ { "on_stderr": { ch, msg -> purescript#ide#utils#warn(purescript#ide#utils#toString(msg), v:true) }
	\ , "on_stdout": { ch, msg -> type(msg) == v:t_string ? purescript#ide#utils#log(msg) : v:null }
	\ , "on_exit": function("s:onServerExit")
	\ }
	\ )
  lcd -

  sleep 100m
  call purescript#ide#setStarted(v:true)
endfunction

let s:onServerExit = v:true
function! s:onServerExit(ch, msg, ev)
  if s:onServerExit
    call purescript#ide#utils#log(purescript#ide#utils#toString(a:ev), v:true)
  else
    call purescript#ide#setStarted(v:false)
  endif
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
    return {'picked': v:false, 'option': v:null}
  endif
endfunction

" END ------------------------------------------------------------------------
" Tell the `purs ide server` to quit
function! PSCIDEend()
  if purescript#ide#external()
    return
  endif
  let jobid = async#job#start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "on_exit": {job, status, ev -> s:PSCIDEendCallback() }
	\ , "on_stderr": {err -> purescript#ide#utils#log(string(err), v:true)}
	\ })
  call async#job#send(jobid, json_encode({'command': 'quit'}) . "\n")
endfunction

function! s:PSCIDEendCallback() 
  call purescript#ide#setStarted(v:false)
  call purescript#ide#setValid(v:false)
endfunction

function! s:projectProblems()
  let rootdir = purescript#ide#utils#findRoot()
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
function! PSCIDEload(logLevel, bang)

  if a:bang == "!"
    return purescript#ide#call(
      \ {"command": "reset"},
      \ "failed to reset",
      \ 0,
      \ { resp -> resp["resultType"] == "success" ? PSCIDEload(a:logLevel, "") : "" }
      \ )
  endif

  let input = {'command': 'load'}

  call purescript#ide#call(
	\ input,
	\ "Failed to load",
	\ 0,
	\ { resp -> s:PSCIDEloadCallback(a:logLevel, resp)}
	\ )
endfunction

function! s:PSCIDEloadCallback(logLevel, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
  call purescript#ide#utils#log(tolower(a:resp["result"]))
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
function! PSCIDEimportIdentifier(ident)
  call s:importIdentifier(a:ident, "")
endfunction
function! s:importIdentifier(ident, module)

  call purescript#ide#utils#debug('PSCIDEimportIdentifier', 3)
  call purescript#ide#utils#debug('ident: ' . a:ident, 3)

  if (a:ident == "")
    return
  endif

  let file = fnamemodify(bufname(""), ":p")

  let input = { 
        \ 'command': 'import' ,
        \ 'params': {
        \   'file': file, 
	\   'outfile': file,
        \   'importCommand': {
        \     'importCommand': 'addImport',
        \     'identifier': a:ident
        \   } } }

  if a:module != ""
    let input.params.filters = [s:modulesFilter([a:module])]
  endif

  let view = winsaveview()
  let lines = line("$")
  " updated the file
  update

  call purescript#ide#call(
	\ input,
	\ "Failed to import identifier " . a:ident, 
	\ 0,
	\ {resp -> s:PSCIDEimportIdentifierCallback(resp, a:ident, view, lines)},
	\ v:true
	\ )
endfunction

fun! PSCIDEcompleteIdentifier(argLead, cmdLead, cursorPos)
  let res = s:completeFn(v:false, a:argLead, { ident, qualifer ->
	\ {'command': 'complete'
	\ , 'params':
	\   { 'matcher': s:flexMatcher(a:argLead)
	\   , 'options': { 'groupReexports': v:true }
	\   }
	\ }
	\ })
  return join(uniq(sort(map(res, {idx, r -> r.word}))), "\n")
endfun

fun! s:FilterTopFn(module, modules)
  " module :: Array String
  " modules :: Array (Array String)
  let mods = map(copy(g:psc_ide_filter_submodules_do_not_hide), { idx, m -> split(m, '\.') })
  return empty(filter(copy(a:modules), { idx, m -> s:IsSubmodule(a:module, m, mods) }))
endfun

fun! s:IsSubmodule(m1, m2, mods)
  " is m1 a submodule of m2
  " m1 :: Array String
  " m2 :: Array String
  if index(a:mods, a:m1) != -1
    let res = v:false
  else
    if len(a:m1) > len(a:m2)
      let res = a:m1[0:len(a:m2)-1] == a:m2 ? v:true : v:false
    else
      let res = v:false
    endif
  endif
  return res
endfun

fun! s:FilterTop(respResults)
  let modules = map(copy(a:respResults), { idx, r -> split(r.module, '\.') })
  call filter(a:respResults, { idx, r -> s:FilterTopFn(split(r.module, '\.'), modules) })
endfun

fun! s:FilterPrelude(respResults)
  call filter(a:respResults, { idx, r -> index(g:psc_ide_prelude, r.module) == -1 })
endfun

function! s:PSCIDEimportIdentifierCallback(resp, ident, view, lines) 
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif

  if type(a:resp.result) == v:t_list
    " multiple possibilities
    let respResults = a:resp.result
    if g:psc_ide_filter_prelude_modules && len(filter(copy(respResults), { idx, r -> r.module ==# "Prelude" }))
      " filter prelude modules (hopefully there are no identifires in prelude
      " that clash
      call s:FilterPrelude(respResults)
    endif
    if g:psc_ide_filter_submodules
      call s:FilterTop(respResults)
    endif
    let results = []
    for res in respResults
      if empty(filter(copy(results), { idx, val -> val.module == res.module }))
	call add(results, res)
      endif
    endfor
    if (len(results) == 1)
      let choice = { "option": results[0], "picked": v:true }
    else
      let choice = s:pickOption("Multiple possibilities to import " . a:ident, results, "module")
    endif
    if choice.picked == v:true
      call s:importIdentifier(a:ident, choice.option.module)
    endif
    return
  endif

  let ar = &l:autoread
  let &l:ar = 1
  checktime %
  let &l:ar = ar
  let a:view.lnum = a:view.lnum + line("$") - a:lines
  call winrestview(a:view)

  " trigger PSCIDErebuild through autocmd
  update
endfunction

function! PSCIDEgoToDefinition(ident)
  let currentModule = s:ExtractModule()
  call purescript#ide#call(
	\ {'command': 'type', 'params': {'search': a:ident, 'filters': []}, 'currentModule': currentModule},
	\ 'Failed to get location info for: ' . a:ident,
	\ 0,
	\ { resp -> s:PSCIDEgoToDefinitionCallback(a:ident, resp) }
	\ )
endfunction

function! s:PSCIDEgoToDefinitionCallback(ident, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
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
  if len(results) > 1
    let choice = s:pickOption("Multiple possibilities for " . a:ident, results, "module")
  elseif len(results) == 1
    let choice = {"picked": v:true, "option": results[0]}
  else
    let choice = {"picked": v:false, "option": v:null}
  endif
  if choice.picked && type(choice.option.definedAt) == type({})
    call s:goToDefinition(choice.option.definedAt)
  elseif type(choice.option) == v:t_dict
    call purescript#ide#utils#warn("no location information found for: " . a:ident . " in module " . choice.option.module)
  else
    call purescript#ide#utils#warn("no location information found for: " . a:ident)
  endif
endfunction

function! s:goToDefinition(definedAt)
  let currentfile = expand("%:p")
  let fname = a:definedAt.name
  let cwd = purescript#ide#utils#findRoot()
  let fname = fnameescape(findfile(fname, cwd))
  if (currentfile == fname)
    " set ' mark at the current position
    m'
    call cursor(a:definedAt.start[0], a:definedAt.start[1])
  else
    call purescript#ide#utils#debug("PSCIDE s:goToDefinition: fname: " . fname, 3)

    let command = "e +" . a:definedAt.start[0] . " " . fname
    call purescript#ide#utils#debug("PSCIDE s:goToDefinition: command: " . command, 3)
    exe command
    exe "normal " . a:definedAt.start[1] . "|"
  endif
endfunction

function! PSCIDErebuild(async, ...)

  let filename = expand("%:p")
  let input = {'command': 'rebuild', 'params': {'file': filename}}

  if a:0 >= 1 && type(a:1) == v:t_func
    let CallBack = a:1
  else
    let CallBack = {resp -> resp}
  endif

  if a:0 >= 2
    let silent = a:2
  else
    let silent = v:false
  endif

  if a:async
    call purescript#ide#call(
	  \ input,
	  \ "failed to rebuild",
	  \ 0,
	  \ { msg -> CallBack(s:PSCIDErebuildCallback(filename, msg, silent)) }
	  \ )
  else
    let resp = s:PSCIDErebuildCallback(
	      \ filename,
	      \ purescript#ide#callSync(input, 0, 0),
	      \ silent
	      \ )
    return CallBack(resp)
  endif
endfunction

function! s:PSCIDErebuildCallback(filename, resp, silent) 
  let g:psc_ide_suggestions = {}
  if type(a:resp) == v:t_dict && has_key(a:resp, "resultType") 
     \ && has_key (a:resp, "result") && type(a:resp.result) == v:t_list
    let out = s:qfList(a:filename, a:resp.result, a:resp.resultType)

    let g:psc_ide_suggestions = out.suggestions
    return out.qfList
  else
    if !a:silent
      call purescript#ide#utils#error("failed to rebuild")
    endif
    return []
  endif
endfunction

" Add type annotation
function! PSCIDEaddTypeAnnotation(ident)
  call s:getType(
	\ a:ident,
	\ v:true,
	\ { resp -> s:PSCIDEaddTypeAnnotationCallback(a:ident, resp) }
	\ )
endfunction

function! s:PSCIDEaddTypeAnnotationCallback(ident, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
  if !empty(a:resp["result"])
    let result = a:resp["result"]
    let lnr = line(".")
    let indent = matchstr(getline(lnr), '^\s*\ze')
    call append(lnr - 1, indent . s:StripNewlines(result[0]['identifier']) . ' :: ' . s:StripNewlines(result[0]["type"]))
  else
    call purescript#ide#utils#warn("no type information found for " .a:ident)
  endif
endfunction

" CWD ------------------------------------------------------------------------
" Get current working directory of `pure ide server`
function! PSCIDEcwd()
  call purescript#ide#call(
	\ {'command': 'cwd'},
	\ "Failed to get current working directory", 
	\ 0,
	\ function("s:PSCIDEcwdCallback")
	\ )
endfunction

function! s:PSCIDEcwdCallback(resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
  call purescript#ide#utils#log("current working directory: " . a:resp.result)
endfunction

" ADDCLAUSE
" Makes template function implementation from signature
function! PSCIDEaddClause()
  let lnr = line(".")
  let line = getline(lnr)

  let command = {'command': 'addClause', 'params': {'line': line, 'annotations': v:false}}

  call purescript#ide#call(
	\ command,
	\ "Failed to add clause",
	\ 0,
	\ { resp -> s:PSCIDEaddClauseCallback(lnr, resp) }
	\ )
endfunction

function! s:PSCIDEaddClauseCallback(lnr, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif

  call purescript#ide#utils#debug('PSCIDEaddClause results: ' . string(a:resp.result), 3)
  call append(a:lnr, a:resp.result)
  normal dd
endfunction

" CASESPLIT
" Hover cursor over variable in function declaration -> pattern match on all
" different cases of the variable
function! PSCIDEcaseSplit(type)
  let winview = winsaveview()
  let lnr = line(".")
  let begin = s:findStart()
  let line = getline(lnr)
  let len = len(matchstr(line[begin:], '^\k*'))
  let word = line[:len]

  call winrestview(winview)

  let command = {
	\ 'command': 'caseSplit',
	\ 'params': { 'line': line, 'begin': begin, 'end': begin + len, 'annotations': v:false, 'type': a:type}
	\ }

  call purescript#ide#call(
	\ command,
	\ 'Failed to split case for: ' . word,
	\ 0,
	\ { resp -> s:PSCIDEcaseSplitCallback(lnr, resp) }
	\ )
endfunction

function! s:PSCIDEcaseSplitCallback(lnr, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
  call append(a:lnr, a:resp.result)
  normal dd
endfunction

" TYPE -----------------------------------------------------------------------
" Get type of word under cursor
function! PSCIDEtype(ident, filterModules)
  call s:getType(
	\ a:ident,
	\ a:filterModules,
	\ { resp -> s:PSCIDEtypeCallback(a:ident, resp.result, a:filterModules) }
	\ )
endfunction

function! s:PSCIDEtypeCallback(ident, result, filterModules)
  if !empty(a:result) && type(a:result) == v:t_list
    for e in a:result
      echom s:formattype(e)
    endfor
  elseif a:filterModules
    call PSCIDEtype(a:ident, v:false)
  else
    call purescript#ide#utils#log("no type information found for " . a:ident)
  endif
endfunction

" LISTIMPORTS -----------------------------------------------------------------------
" List the modules imported by the current module
function! PSCIDElistImports()
  let currentModule = s:ExtractModule()
  call purescript#ide#utils#debug('PSCIDElistImports ' . currentModule, 3)
  let imports =  s:ListImports(currentModule)
  for import in imports
    call s:echoImport(import)
  endfor
  if (len(imports) == 0)
    echom "PSC-IDE: No import information found for " . currentModule
  endif

endfunction

function! s:echoImport(import)
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
  let resp = purescript#ide#callSync(
	\ {'command': 'list', 'params': {'type': 'import', 'file': filename}},
	\ 'Failed to get imports for: ' . a:module,
	\ 0
	\ )
  call purescript#ide#utils#debug("PSCIDE s:ListImports result: " . string(resp), 3)
  " Only need module names right now, so pluck just those.
  if type(resp) == v:t_dict && resp['resultType'] ==# 'success'
    " psc-ide >=0.11 returns imports on 'imports' property.
    return type(resp.result) == v:t_list ? resp.result : resp.result.imports
  else
    call purescript#ide#handlePursError(resp)
  endif
endfunction

function! s:getType(ident, filterModules, cb)
  let currentModule = s:ExtractModule()
  if a:filterModules
    let modules = add(map(s:ListImports(currentModule), {key, val -> val["module"]}), currentModule)
    let filters = [s:modulesFilter(modules)]
  else
    let filters = []
  endif
  call purescript#ide#utils#debug('PSCIDE s:getType currentModule: ' . currentModule, 3)

  call purescript#ide#call(
	\ { 'command': 'type'
	\ , 'params':
	\     { 'search': a:ident
	\     , 'filters': filters
	\     , 'currentModule': currentModule
	\     }
	\ },
	\  'Failed to get type info for: ' . a:ident,
	\ 0,
	\ {resp -> a:cb(resp)}
	\ )
endfunction

function! s:formattype(record)
  return s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['identifier']) . ' ∷ ' . s:StripNewlines(a:record['type']))
endfunction

" APPLYSUGGESTION ------------------------------------------------------
" Apply suggestion in loclist to buffer --------------------------------
function! PSCIDEapplySuggestion(bang)
  if empty(a:bang)
    call PSCIDEapplySuggestionPrime(expand("%:p") . "|" . line("."), v:true, 0)
  else
    let l = 0
    let len = len(keys(g:psc_ide_suggestions))
    while l < len
      " PSCIDEapplySuggestionPrime will change g:psc_ide_suggestions keys on
      " the fly
      let keys = keys(g:psc_ide_suggestions)
      if len(keys) > 0
	let key = keys[0]
	call PSCIDEapplySuggestionPrime(key, v:true, 0)
      else
	break
      endif
    endwhile
  endif
endfunction

function! PSCIDEapplySuggestionPrime(key, cursor, silent)

  call purescript#ide#utils#debug('PSCIDEapplySuggestion: a:key: ' . a:key, 3)

  if (has_key(g:psc_ide_suggestions, a:key))
    let sugg = g:psc_ide_suggestions[a:key]
  else
    if !a:silent
      call purescript#ide#utils#debug('PSCIDEapplySuggestion: No suggestion found', 0)
    endif
    return
  endif

  call purescript#ide#utils#debug('PSCIDEapplySuggestion: Suggestion found: ' . string(sugg), 3)
  let replacement = sugg.replacement
  let range = sugg.replaceRange
  let startLine = range.startLine
  let startColumn = range.startColumn
  let endLine = range.endLine
  let endColumn = range.endColumn
  if startLine == endLine
    let line = getline(startLine)
    let replacement = substitute(replacement, '\_s*$', '\n', '')
    let cursor = getcurpos()
    if startColumn == 1
      let newLines = split(replacement . line[endColumn - 1:], "\n")
    else
      let newLines = split(line[0:startColumn - 2] . replacement . line[endColumn - 1:], "\n")
    endif
    exe startLine . "d _"
    call append(startLine - 1, newLines)
    if a:cursor
      call cursor(cursor[1], startColumn - 1)
    endif
    call remove(g:psc_ide_suggestions, a:key)
    let g:psc_ide_suggestions = s:updateSuggestions(startLine, len(newLines) - 1)

    " trigger PSCIDErebuild through autocmd
    update
  else
    echom "PSCIDEapplySuggestion: multiline suggestions are not yet supported"
  endif
endfunction

fun! s:updateSuggestions(startLine, newLines)
  let suggestions = {}
  for key in keys(g:psc_ide_suggestions)
    let sug = g:psc_ide_suggestions[key]
    if sug.replaceRange.startLine < a:startLine
      let suggestions[key] = sug
    else
      let keyParts = split(key, "|")
      let keyParts[len(keyParts) - 1] = sug.replaceRange.startLine + a:newLines
      let newKey = join(keyParts, "|")
      let sug.replaceRange.startLine = sug.replaceRange.startLine + a:newLines
      let sug.replaceRange.endLine = sug.replaceRange.endLine + a:newLines
      let suggestions[newKey] = sug
    endif
  endfor
  return suggestions
endfun

" Add all import qualifications
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
  call purescript#ide#utils#debug('Adding import qualifications to : ' . string(foundLines), 3)

  for lnr in foundLines
    call PSCIDEapplySuggestionPrime(lnr, filename, 1)
  endfor

  call cursor(oldCursorPos[1], oldCursorPos[2])
endfunction


" PURSUIT --------------------------------------------------------------------
function! PSCIDEpursuit(ident)

  call purescript#ide#call(
	\ {'command': 'pursuit', 'params': {'query': a:ident, 'type': "completion"}},
	\ 'Failed to get pursuit info for: ' . a:ident,
	\ 0,
	\ { resp -> s:PSCIDEpursuitCallback(resp) }
	\ )
endfunction

function! s:PSCIDEpursuitCallback(resp)
  if type(a:resp) == v:t_dict && a:resp['resultType'] ==# 'success'
    if len(a:resp["result"]) > 0
      for e in a:resp["result"]
        echom s:formatpursuit(e)
      endfor
    else
      call purescript#ide#utils#error(get(a:resp, "result", "error"))
    endif
  endif
endfunction

function! s:formatpursuit(record)
  return "In " . s:CleanEnd(s:StripNewlines(a:record["package"])) . " " . s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['ident']) . ' :: ' . s:StripNewlines(a:record['type']))
endfunction

" VALIDATE -------------------------------------------------------------------
function! PSCIDEprojectValidate()
  let problems = s:projectProblems()

  if len(problems) == 0
    call purescript#ide#setValid(v:true)
    echom "Your project is setup correctly."
  else
    call purescript#ide#setValid(v:true)
    echom "Your project is not setup correctly. " . join(problems)
  endif
endfunction

" LIST -----------------------------------------------------------------------
function! PSCIDElist()
  let resp = purescript#ide#callSync(
	\ {'command': 'list', 'params': {'type': 'loadedModules'}},
	\ 'Failed to get loaded modules',
	\ 0
	\ )
  call s:PSCIDElistCallback(resp)
endfunction

function! s:PSCIDElistCallback(resp)
  if type(a:resp) == v:t_dict && a:resp['resultType'] ==# 'success'
    if len(a:resp["result"]) > 0
      for m in a:resp["result"]
        echom m
      endfor
    endif
  elseif type(a:resp) == v:t_dict
    call purescript#ide#utils#error(get(a:resp, "result", "error"))
  endif
endfunction

fun! s:findStart()
  let col   = col(".")
  let line  = getline(".")

  " search backwards for start of identifier (iskeyword pattern)
  let start = col
  while start > 0 && (line[start - 2] =~ '\k' || line[start - 2] =~ '\.')
    let start -= 1
  endwhile

  "Looking for the start of the identifier that we want to complete
  return start - 1
endfun

" COMPLETION FUNCTION --------------------------------------------------------
fun! s:completeFn(findstart, base, commandFn)
  if a:findstart 
    return s:findStart()
  else

    if match(a:base, '\.') != -1
      let str_ = split(a:base, '\.')
      let qualifier = join(str_[0:len(str_)-2], ".")
      let ident= str_[len(str_) - 1]
    else
      let ident = a:base
      let qualifier = ""
    endif

    let resp = purescript#ide#callSync(
	  \ a:commandFn(ident, qualifier),
	  \ 'Failed to get completions for: '. a:base,
	  \ 0)

    let entries = get(resp, "result", [])
    "Popuplating the omnicompletion list
    let result = []

    let hasPreview = index(split(&l:completeopt, ','), 'preview') != -1
    " vimL does not have compare function for strings, and uniq must run after
    " sort.
    if g:psc_ide_omnicompletion_sort_by != "flex"
      call uniq(
	    \ sort(entries, { e1, e2 -> 
		  \ g:psc_ide_omnicompletion_sort_by == "module" 
		    \ ? e1.module == e2.module
		    \ : sort([e1.identifier, e2.identifier]) == [e2.identifier, e1.identifier]}),
	    \ { e1, e2 -> !s:compareByDefinedAt(e1, e2) }
	    \ )
    endif

    for entry in entries
      let detail = printf("\t%-25S\t\t%s", entry['module'], entry["type"])
      let e = { 'word': (empty(qualifier) ? "" : qualifier . ".") . entry['identifier']
	    \ , 'menu': hasPreview ? entry["type"] : detail
	    \ , 'info': detail
	    \ , 'dup': 1
	    \ }
      call add(result, e)
    endfor
    return result
  endif
endfun

fun! s:omniCommand(ident, qualifier)
  let currentModule = s:ExtractModule()

  let filters = []
  if g:psc_ide_omnicompletion_prefix_filter
    call add(filters, s:prefixFilter(a:ident))
  endif

  if !empty(a:qualifier)
    let imports = s:ListImports(currentModule)
    let modules = []
    for mod in imports
      if get(mod, "qualifier", "") == a:qualifier || get(mod, "module", "") == a:qualifier
	call add(modules, mod.module)
      endif
    endfor

    if len(modules)
      call add(filters, s:modulesFilter(modules))
    endif
    let matcher = s:flexMatcher(a:ident)
  else
    if g:psc_ide_omnicompletion_filter_modules
      call add(filters, s:modulesFilter(map(s:ListImports(currentModule), { n, m -> m.module })))
    endif
    let matcher = s:flexMatcher(a:ident)
  endif

  return {'command': 'complete'
	 \ , 'params':
	 \   { 'filters': filters
	 \   , 'matcher': matcher
	 \   , 'currentModule': currentModule
	 \   , 'options': { 'groupReexports': v:true }
	 \   }
	 \ }
endfun

fun! s:compareByDefinedAt(e1, e2)
  let d1 = get(a:e1, "definedAt", v:null)
  let d2 = get(a:e2, "definedAt", v:null)
  if type(d1) != v:t_dict || type(d2) != v:t_dict
    return v:false
  endif
  if d1["name"] != d2["name"]
	\ || d1["start"][0] != d2["start"][0]
	\ || d1["start"][1] != d2["start"][1]
	\ || d1["end"][0] != d2["end"][0]
	\ || d1["end"][1] != d2["end"][1]
    return v:false
  else
    return v:true
  endif
endfun

function! s:prefixFilter(s) 
  return { "filter": "prefix", "params": { "search": a:s } }
endfunction

function! s:flexMatcher(s)
  return { "matcher": "flex", "params": { "search": a:s } }
endfunction

fun! s:modulesFilter(modules)
  return { "filter": "modules", "params": { "modules": a:modules } }
endfun

" SET UP OMNICOMPLETION ------------------------------------------------------
fun! PSCIDEomni(findstart, base)
  if a:findstart
    return s:completeFn(a:findstart, a:base, function("s:omniCommand"))
  else
    let results = s:completeFn(a:findstart, a:base, function("s:omniCommand"))
    if empty(results)
      let results = PSCIDEcomplete(a:findstart, a:base)
    endif
    return results
  endif
endfun

" SET UP USERCOMPLETION ------------------------------------------------------
fun! PSCIDEcomplete(findstart, base)
  return s:completeFn(a:findstart, a:base, { ident, qualifier ->
	\ {'command': 'complete'
	\ , 'params':
	\   { 'matcher': s:flexMatcher(a:base)
	\   , 'options': { 'groupReexports': v:true }
	\   }
	\ }
	\ })
endfun

" SEARCH ---------------------------------------------------------------------
fun! PSCIDEsearch(ident)
  let matcher = s:flexMatcher(a:ident)
  call purescript#ide#call(
	\ {'command': 'complete'
	\ , 'params':
	\   { 'matcher': matcher
	\   , 'options': { 'groupReexports': v:true }
	\   }
	\ },
	\ 'Failed to get completions for: '. a:ident,
	\ 0,
	\ { resp -> s:searchFn(resp) }
	\ )
endfun

fun! s:searchFn(resp)
  if get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#utils#error(get(a:resp, "result", "error"))
  endif
  let llist = []
  for res in get(a:resp, "result", [])
    let llentry = {}
    let bufnr = bufnr(res.definedAt.name)
    if bufnr != -1
      let llentry.bufnr = bufnr
    endif
    let llentry.filename = res.definedAt.name
    let llentry.module = res.module
    let llentry.lnum = res.definedAt.start[0]
    let llentry.col = res.definedAt.start[1]
    let llentry.text = printf("%s %s", res.identifier, res.type)
    call add(llist, llentry)
  endfor
  " echom json_encode(a:resp)
  call setloclist(0, llist)
  call setloclist(0, [], 'a', {'title': 'PureScript Search'})
  lopen
endfun

" PSCIDE HELPER FUNCTION -----------------------------------------------------
" Issues the commands to the server
" Is responsible for keeping track of whether or not we have a running server
" and (re)starting it if not
" Also serializes and deserializes from/to JSON
" ADD IMPORTS  --------------------------------------------------------------
fun! PSCIDEimportModule(module)
  let args = filter(split(a:module, ' '), { idx, p -> p != ' ' })
  if len(args) >= 2
    let importCommand =
	  \ { "importCommand": "addQualifiedImport"
	  \ , "module": args[0]
	  \ , "qualifier": args[1]
	  \ }
  else
    let importCommand =
	  \ { "importCommand": "addImplicitImport"
	  \ , "module": args[0]
	  \ }
  endif
  let params =
	\ { "file": expand("%:p")
	\ , "importCommand": importCommand
	\ }

  call purescript#ide#call(
	\ { "command": "import" , "params": params }
	\ , "failed to add import",
	\ 0,
	\ function("s:PSCIDEimportModuleCallback"),
	\ v:true
	\ )
endfun

fun! s:PSCIDEimportModuleCallback(resp)
  if type(a:resp) == v:t_dict && a:resp.resultType ==# "success"
    let view = winsaveview()
    %d_
    call append(0, a:resp.result)
    $d_
    let view.lnum += 1
    let view.topline += 1
    call winrestview(view)
  else
    call purescript#ide#utils#error(get(a:resp, "result", "error"))
  endif

  " trigger PSCIDErebuild through autocmd
  update
endfun

fun! PSCIDEimportModuleCompletion(ArgLead, CmdLine, CursorPos)
  let resp = purescript#ide#callSync(
	\ {'command': 'list', 'params': {'type': 'loadedModules'}},
	\ 'Failed to get loaded modules',
	\ 0
	\ )
  if type(resp) == v:t_dict && resp.resultType == "success"
    return join(resp.result, "\n")
  else
    return ""
  endif
endfun

" UTILITY FUNCTIONS ----------------------------------------------------------

function! s:StripNewlines(s)
  return substitute(a:s, '\s*\n\s*', ' ', 'g')
endfunction

function! s:CleanEnd(s)
  return substitute(a:s, '\s*\n*\s*$', '', 'g')
endfunction

" INIT -----------------------------------------------------------------------
function! PSCIDEerrors(llist, ...)
  if a:0 > 1
    let silent = a:1
  else
    let silent = v:false
  endif

  let qfList = []
  for e in a:llist
    if e.bufnr != -1
      let text = split(e.text, '\n')
      call add(
	    \ qfList
	    \ , { "bufnr": e.bufnr
	    \   , "filename": e.filename
	    \   , "lnum": e.lnum
	    \   , "col": e.col
	    \   , "text": text[0]
	    \   , "type": e.type
	    \   }
	    \ )
      for line in text[1:]
	call add(qfList, {"text": line})
      endfor
    endif
  endfor
  if !silent && g:psc_ide_notify
    let errsLen = len(filter(copy(qfList), { n, e -> get(e, "type", "") ==# "E" || get(e, "type", "") ==# "F" }))
    let wrnLen = len(filter(copy(qfList), { n, e -> get(e, "type", "") ==# "W" || get(e, "type", "") ==# "V" }))
    if errsLen > 0
      echohl ErrorMsg
      echom "purs: " . errsLen . " " . (errsLen == 1 ? "error" : "errors")
      echohl Normal
    elseif wrnLen > 0
      echohl WarningMsg
      echom "purs: " . wrnLen . " ". (wrnLen == 1 ? "warning" : "warnings")
      echohl Normal
    else
      call purescript#ide#utils#log("success")
    endif
  endif
  call setqflist(qfList)
  call setqflist([], 'a', {'title': 'PureScript Errors'})
endfunction

" Parse Errors & Suggestions -------------------------------------------------
function! s:qfList(filename, errors, resultType)
  let qfList = []
  let suggestions = {}

  for e in a:errors
    call add(qfList, s:qfEntry(e, a:filename, a:resultType ==# "error"))
    if type(get(e, "suggestion", v:null)) == v:t_dict
      call s:addSuggestion(suggestions, e)
    endif
  endfor

  call sort(qfList, { e1, e2 -> e1["lnum"] == e2["lnum"] ? e1["col"] - e2["col"] : e1["lnum"] - e2["lnum"] })
  return {"qfList": qfList, "suggestions": suggestions}
endfunction

function! s:qfEntry(e, filename, err)
  let isError = a:err == 1
  let hasSuggestion = type(get(a:e, "suggestion", v:null)) == v:t_dict
  let type = isError ? (hasSuggestion ? 'F' : 'E') : (hasSuggestion ? 'V' : 'W')
  let lnum = has_key(a:e, "position") && type(a:e.position) == v:t_dict
	\ ? a:e.position.startLine : 1
  let col = has_key(a:e, "position") && type(a:e.position) == v:t_dict
	\ ? a:e.position.startColumn : 1
  return
	\ { "filename": a:filename
	\ , "bufnr": bufnr(a:filename)
	\ , "lnum": lnum
	\ , "col": col
	\ , "text": a:e.message
	\ , "type": type
	\ }
endfunction

function! s:addSuggestion(suggestions, e)
   let a:suggestions[a:e.filename . "|" . string(a:e.position.startLine)] = a:e.suggestion
endfunction

fun! PSCIDEgetKeyword()
  let isk = &l:isk
  setl isk+=<,>,$,#,+,-,*,/,%,',&,=,!,:,124,~,?,^
  let keyword = expand("<cword>")
  let &l:isk = isk
  return keyword
endfun

" AUTOSTART ------------------------------------------------------------------
call s:autoStart()
