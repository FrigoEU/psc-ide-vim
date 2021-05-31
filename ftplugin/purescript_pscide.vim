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

if !exists('g:psc_ide_codegen')
  " js / corefn / sourcemaps
  let g:psc_ide_codegen = ['js']
endif

if !exists('g:psc_ide_import_on_completion')
  let g:psc_ide_import_on_completion = v:true
endif

if !exists("g:psc_ide_omnicompletion_prefix_filter")
  " with this option will let purs ide filter by prefix (this disables flex
  " matching) (tip: use i^xu when searching for a command)
  let g:psc_ide_omnicompletion_prefix_filter = v:true
endif

if !exists('g:psc_ide_log_level')
  let g:psc_ide_log_level = 0
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

" Check if vim has support for module names (non standard)
let loclist = getloclist(0)
call setloclist(0, [{"module": "X"}])
let s:vim_module_names = has_key(get(getloclist(0), 0, {}), "module")
call setloclist(0, loclist)

" COMMANDS -------------------------------------------------------------------
com! -buffer -bang
      \ PaddClause
      \ call PSCIDEaddClause(<q-bang>)
com! -buffer
      \ PaddImportQualifications
      \ call PSCIDEaddImportQualifications()
com! -buffer
      \ PaddType
      \ call PSCIDEaddTypeAnnotation(matchstr(getline(line(".")), '^\s*\zs\k\+\ze'))
com! -buffer -bang
      \ Papply
      \ call PSCIDEapplySuggestion(<q-bang>)
com! -buffer -bang -nargs=1
      \ Pcase
      \ call PSCIDEcaseSplit(<q-bang>, <q-args>)
com! -buffer
      \ Pcwd
      \ call PSCIDEcwd()
com! -buffer
      \ Pend
      \ call PSCIDEend()
com! -buffer -nargs=* -bang -complete=custom,PSCIDEcompleteIdentifier 
      \ Pgoto
      \ call PSCIDEgoToDefinition(<q-bang>, len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer -nargs=* -complete=custom,PSCIDEcompleteIdentifier
      \ Pimport
      \ call PSCIDEimportIdentifier(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer
      \ Plist
      \ call PSCIDElist()
com! -buffer
      \ Pimports
      \ call PSCIDElistImports()
com! -buffer -bang
      \ Pload
      \ call PSCIDEload(0, <q-bang>)
com! -buffer Pvalidate
      \ call PSCIDEprojectValidate(v:false)
com! -buffer -nargs=*
      \ Pursuit
      \ call PSCIDEpursuit(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer -bang
      \ Prebuild
      \ call PSCIDErebuild(v:true, <q-bang>, function("PSCIDEerrors"))
com! -buffer
      \ Pstart
      \ call PSCIDEstart(0)
com! -buffer -nargs=* -complete=custom,PSCIDEcompleteIdentifier
      \ Ptype
      \ call PSCIDEtype(len(<q-args>) ? <q-args> : PSCIDEgetKeyword(), v:true)
com! -buffer -nargs=1 -complete=custom,PSCIDEcompleteIdentifier
      \ Psearch
      \ call PSCIDEsearch(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())
com! -buffer -nargs=* -complete=custom,PSCIDEimportModuleCompletion
      \ PimportModule
      \ call PSCIDEimportModule(len(<q-args>) ? <q-args> : PSCIDEgetKeyword())

" AUTOSTART ------------------------------------------------------------------
fun! s:autoStart()
  if exists("g:psc_ide_syntastic_mode") && g:psc_ide_syntastic_mode == 0
    augroup purescript
      au! BufWritePost *.purs call PSCIDErebuild(v:true, "", function("PSCIDEerrors"))
      au! BufAdd *.purs call PSCIDErebuild(v:true, "", function("PSCIDEerrors"))
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

augroup purescript_CompleteDone
  au!
  au CompleteDone * :call purescript#ide#import#completeDone()
augroup END

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
    echom "No psc-package.json, bower.json or spago.dhall found, couldn't start `purs ide server`"
    return
  endif
  
  let command = [ 
	\ "purs", "ide", "server",
	\ "-p", g:psc_ide_server_port,
	\ "-d", dir,
	\ "src/**/*.purs",
	\ "bower_components/**/*.purs",
	\ ]

  if executable("spago")
    let fullCommand = command + systemlist("spago sources") 
  else
    let fullCommand = command
  endif

  exe "lcd" dir
  call purescript#ide#utils#debug("PSCIDEstart: " . json_encode(fullCommand), 3)
  let jobid = purescript#job#start(
	\ fullCommand,
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


" END ------------------------------------------------------------------------
" Tell the `purs ide server` to quit
function! PSCIDEend()
  if purescript#ide#external()
    return
  endif
  let jobid = purescript#job#start(
	\ ["purs", "ide", "client", "-p", g:psc_ide_server_port],
	\ { "on_exit": {job, status, ev -> s:PSCIDEendCallback() }
	\ , "on_stderr": {err -> purescript#ide#utils#log(string(err), v:true)}
	\ })
  call purescript#job#send(jobid, json_encode({'command': 'quit'}) . "\n")
endfunction

function! s:PSCIDEendCallback() 
  call purescript#ide#setStarted(v:false)
  call purescript#ide#setValid(v:false)
endfunction

function! s:projectProblems()
  let rootdir = purescript#ide#utils#findRoot()
  let problems = []

  if empty(rootdir)
    call add(problems, "Your project is missing a bower.json, psc-package.json or spago.dhall file")
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
function! PSCIDEload(logLevel, bang, ...)
  let hasCb = a:0 >= 1 && type(a:1) == v:t_func

  if hasCb
    let Fn = { resp -> a:1(s:PSCIDEloadCallback(a:logLevel, resp)) }
  else
    let Fn = { resp -> s:PSCIDEloadCallback(a:logLevel, resp) }
  endif

  if a:bang == "!"
    return purescript#ide#call(
      \ {"command": "reset"},
      \ "failed to reset",
      \ 0,
      \ { resp -> resp["resultType"] == "success" ? PSCIDEload(a:logLevel, "", hasCb ? a:1 : v:null) : "" }
      \ )
  endif

  let input = {'command': 'load'}

  call purescript#ide#call(
	\ input,
	\ "Failed to load",
	\ 0,
	\ Fn
	\ )
endfunction

function! s:PSCIDEloadCallback(logLevel, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
  call purescript#ide#utils#log(tolower(a:resp["result"]))
  return a:resp
endfunction

" Import given identifier
function! PSCIDEimportIdentifier(ident)
  call purescript#ide#import#identifier(a:ident, "")
endfunction

fun! s:completeCommand(ident, qualifier, ...)
  let currentModule = purescript#ide#utils#currentModule()
  let modules = a:0 >= 1 ? a:1 : v:null
  if type(modules) == v:t_list
    let filters = [purescript#ide#utils#modulesFilter(modules)]
  elseif !empty(a:qualifier)
    let modules = map(purescript#ide#import#listImports(currentModule, a:qualifier), { idx, val -> val["module"] })
    let filters = [purescript#ide#utils#modulesFilter(modules)]
  else
    let filters = []
  endif
  return
	\ {'command': 'complete'
	\ , 'params':
	\   { 'matcher': empty(a:ident) ? {} : s:flexMatcher(a:ident)
	\   , 'options': { 'groupReexports': v:true }
	\   , 'filters': filters
	\   }
	\ }
endfun

fun! PSCIDEcompleteIdentifier(argLead, cmdLead, cursorPos)
  let res = s:completeFn(v:false, a:argLead, function("s:completeCommand"))
  return join(uniq(sort(map(res, {idx, r -> r.word}))), "\n")
endfun

function! PSCIDEgoToDefinition(bang, ident)
  let currentModule = purescript#ide#utils#currentModule()
  let [ident, qualifier] = purescript#ide#utils#splitQualifier(a:ident)
  let imports = purescript#ide#import#listImports(currentModule, qualifier, a:bang != "!" ? ident : "")
  if a:bang == "!"
    if empty(qualifier)
      let filters = []
    else
      let modules = map(copy(imports), {key, val -> val["module"]})
      let filters = [purescript#ide#utils#modulesFilter(modules)]
    endif
  else
    let modules = map(copy(imports), {key, val -> val["module"]})
    call add(modules, currentModule)
    call add(modules, "Prim")
    let filters = [purescript#ide#utils#modulesFilter(modules)]
  endif
  call purescript#ide#call(
	\ {'command': 'type', 'params': {'search': ident, 'filters': filters}, 'currentModule': currentModule},
	\ 'Failed to get location info for: ' . a:ident,
	\ 0,
	\ { resp -> s:PSCIDEgoToDefinitionCallback(a:bang, a:ident, resp) }
	\ )
endfunction

function! s:PSCIDEgoToDefinitionCallback(bang, ident, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
  let results = []
  for res in a:resp.result
    if empty(filter(copy(results), { idx, val -> 
	  \    type(val.definedAt) == v:t_dict
	  \ && type(res.definedAt) == v:t_dict
	  \ && val.definedAt.name == res.definedAt.name
	  \ && val.definedAt.start[0] == res.definedAt.start[0]}))
      call add(results, res)
    endif
  endfor
  if a:bang != "!" && empty(results)
    " try again with a bang
    return PSCIDEgoToDefinition("!", a:ident)
  endif
  if len(results) > 1
    let choice = purescript#ide#utils#pickOption("Multiple possibilities for " . a:ident, results, "module")
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

function! PSCIDErebuild(async, bang, ...)

  let filename = expand("%:p")
  let input = {'command': 'rebuild', 'params': {'file': filename, 'codegen': g:psc_ide_codegen}}

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
    if a:bang == "!"
      call PSCIDEload(0, "!", { resp -> PSCIDErebuild(a:async, "", CallBack )})
    else
      call purescript#ide#call(
	    \ input,
	    \ "failed to rebuild",
	    \ 0,
	    \ { msg -> CallBack(s:PSCIDErebuildCallback(filename, msg, silent)) }
	    \ )
    endif
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
function! PSCIDEaddClause(bang)
  let lnr = line(".")
  let line = getline(lnr)

  let command = {
	\ 'command': 'addClause',
	\ 'params':
	\   { 'line': line
	\   , 'annotations': a:bang == "!" ? v:true : v:false
	\   }
	\ }

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
function! PSCIDEcaseSplit(bang, ...)
  if (a:0 >= 1)
    let type = a:1
  else
    let type = input("Please provide a type: ")
  endif

  let winview = winsaveview()
  let lnr = line(".")
  let begin = s:findStart()
  let line = getline(lnr)
  let len = len(matchstr(line[begin:], '^\k*'))
  let word = line[:len]

  call winrestview(winview)

  let command = {
	\ 'command': 'caseSplit',
	\ 'params':
	\   { 'line': line
	\   , 'begin': begin
	\   , 'end': begin + len
	\   , 'annotations': a:bang == "!" ? v:true : v:false
	\   , 'type': type
	\   }
	\ }

  call purescript#ide#call(
	\ command,
	\ 'Failed to split case for: ' . word,
	\ 0,
	\ { resp -> s:PSCIDEcaseSplitCallback(lnr, type, resp) }
	\ )
endfunction

function! s:PSCIDEcaseSplitCallback(lnr, type, resp)
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    if get(a:resp, "result", "") == "Not Found"
      call purescript#ide#utils#error("type `" . a:type . "` not found", v:true)
    else
      call purescript#ide#handlePursError(a:resp)
    endif
    return
  endif
  call append(a:lnr, a:resp.result)
  normal dd
  normal $
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
  if type(a:result) == v:t_list && !empty(a:result)
      let filePadding = min([max(map(copy(a:result), { i, r -> type(r.definedAt) == v:t_dict && has_key(r.definedAt, "name") ? len(r.definedAt.name) : 0})) + 1, 30])
      let modulePadding = min([max(map(copy(a:result), { i, r -> type(r.module) == v:t_string ? len(r.module) : 0})) + 1, 30])
      call setloclist(0, map(a:result, { idx, r -> s:formattype(r, filePadding, modulePadding)}))
      call setloclist(0, [], 'a', {'title': 'PureScript Types'})
      lopen
      wincmd p
  elseif a:filterModules
    call PSCIDEtype(a:ident, v:false)
  else
    call purescript#ide#utils#log("no type information found for " . a:ident)
  endif
endfunction

" LISTIMPORTS -----------------------------------------------------------------------
" List the modules imported by the current module
function! PSCIDElistImports()
  let currentModule = purescript#ide#utils#currentModule()
  call purescript#ide#utils#debug('PSCIDElistImports ' . currentModule, 3)
  let imports =  purescript#ide#import#listImports(currentModule)
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

function! s:getType(ident, filterModules, cb)
  let currentModule = purescript#ide#utils#currentModule()
  let [ident, qualifier] = purescript#ide#utils#splitQualifier(a:ident)
  let imports = purescript#ide#import#listImports(currentModule, qualifier, a:filterModules ? ident : "")
  let modules = map(copy(imports), {key, val -> val["module"]})
  call add(modules, currentModule)
  let filters = [purescript#ide#utils#modulesFilter(modules)]
  call purescript#ide#utils#debug('PSCIDE s:getType currentModule: ' . currentModule, 3)

  call purescript#ide#call(
	\ { 'command': 'type'
	\ , 'params':
	\     { 'search': ident
	\     , 'filters': filters
	\     , 'currentModule': currentModule
	\     }
	\ },
	\  'Failed to get type info for: ' . a:ident,
	\ 0,
	\ {resp -> a:cb(resp)}
	\ )
endfunction

function! s:formattype(record, filePadding, modulePadding)
  let definedAt = a:record.definedAt
  if type(definedAt) != v:t_dict
    " v:null's are ignored by vim's setqflist()
    let definedAt = {"name": "", "start": [v:null, v:null]}
  endif
  let entry =
	\ { "filename": s:vim_module_names ? printf("%-" . a:filePadding . "s", definedAt["name"]) : ""
	\ , "module": empty(a:record["module"]) ? "" : printf("%-" . a:modulePadding . "s", a:record["module"])
	\ , "lnum": definedAt["start"][0]
	\ , "col": definedAt["start"][1]
	\ , "text": s:CleanEnd(s:StripNewlines(a:record['identifier']) . ' ∷ ' . s:StripNewlines(a:record['type']))
	\ }
  return entry
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
    " remove trailing new lines
    let replacement = substitute(replacement, '\_s*$', "\n", '')
    " add identation to each line (except first one)
    " and remove trailing white space from each line
    let RSpace = { line -> substitute(line, '\s*$', '', '') }
    let replacement = join(
	  \ map(
	    \ split(replacement, "\n"),
	    \ { idx, line -> idx == 0 ? RSpace(line) : repeat(" ", startColumn) . RSpace(line)}
	  \ ),
	  \ "\n")
    let cursor = getcurpos()
    if startColumn == 1
      let newLines = split(replacement . "\n" . line[endColumn - 1:], "\n")
    else
      let newLines = split(line[0:startColumn - 2] . replacement . "\n" . line[endColumn - 1:], "\n")
    endif
    exe startLine . "d _"
    call append(startLine - 1, newLines)
    if a:cursor
      call cursor(cursor[1], startColumn - 1)
    endif
    call remove(g:psc_ide_suggestions, a:key)
    let g:psc_ide_suggestions = s:updateSuggestions(startLine, len(newLines) - 1)

    " trigger PSCIDErebuild
    call purescript#ide#utils#update()
    call PSCIDErebuild(v:true, "", function("PSCIDEerrors"))
  else
    call purescript#ide#utils#debug("multiline suggestions are not supported in vim - please grab g:psc_ide_suggestions and open an issue")
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
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    return purescript#ide#handlePursError(a:resp)
  endif
  call setloclist(0, map(a:resp.result, { idx, r -> { "text": s:formatpursuit(r) }}))
  call setloclist(0, [], 'a', {'title': 'Pursuit'})
  lopen
  wincmd p
endfunction

function! s:formatpursuit(record)
  let package = s:CleanEnd(s:StripNewlines(get(a:record, "package", "")))
  let module = s:CleanEnd(s:StripNewlines(get(a:record, "module", "")))
  let ident = s:CleanEnd(s:StripNewlines(get(a:record, "ident", "")))
  let type = get(a:record, "type", "")
  if empty(type)
    let type = ""
  else
    let type = "∷ " . s:CleanEnd(s:StripNewlines(type))
  endif
  return printf("%-20s %s.%s %s", package, module, ident, type)
endfunction

" VALIDATE -------------------------------------------------------------------
function! PSCIDEprojectValidate(silent)
  let problems = s:projectProblems()

  if len(problems) == 0
    call purescript#ide#setValid(v:true)
    if !a:silent
      call purescript#ide#utils#log("your project is setup correctly")
    endif
  else
    call purescript#ide#setValid(v:true)
    call purescript#ide#utils#warn("your project is not setup correctly. " . join(problems))
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
  while start > 0 && (line[start - 2] =~ '\(\k\|[<>$#+*/%''&=!:~?^-]\)' || line[start - 2] =~ '\.')
    let start -= 1
  endwhile

  "Looking for the start of the identifier that we want to complete
  return start - 1
endfun

" COMPLETION FUNCTION --------------------------------------------------------
fun! s:completeFn(findstart, base, commandFn,...)
  let completeImportLine = a:0 >= 1 ? a:1 : v:false

  if a:findstart 
    return s:findStart()
  else

    let [ident, qualifier] = purescript#ide#utils#splitQualifier(a:base)
    let command = v:null

    if completeImportLine
      let line = getline(".")
      let sline = line[0:col(".")-1]
      if sline =~ '^\s*import\s\+[a-zA-Z.]*$'
	let resp = purescript#ide#callSync(
	  \ {"command": "list", "params": {"type": "loadedModules"}},
	  \ "Failed to get loaded modules",
	  \ 0
	  \ )
	let res = get(resp, "result", [])
	if (type(res) != v:t_list)
	  let res = []
	endif
	let len = len(a:base)
	let mlen = len(split(a:base, '\.', v:true))
	return filter(res, { idx, val -> val[0:len-1] == a:base })
      elseif line =~ '^\s*import\s*[a-zA-Z.]\+\s*('
	let moduleName = matchstr(line, '^\s*import\>\s*\<\zs[a-zA-Z.]\+\>\ze')
	let command = a:commandFn(ident, "", [moduleName])
      endif
    endif

    if type(command) != v:t_dict
      let command = a:commandFn(ident, qualifier)
    endif

    if empty(command)
      return
    endif

    let resp = purescript#ide#callSync(
	  \ command,
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

fun! s:omniCommand(ident, qualifier, ...)
  let modules = a:0 >= 1 ? a:1 : v:null
  let currentModule = purescript#ide#utils#currentModule()
  let filters = []

  if g:psc_ide_omnicompletion_prefix_filter
    call add(filters, s:prefixFilter(a:ident))
  endif

  if !empty(a:qualifier)
    let imports = map(purescript#ide#import#listImports(currentModule, a:qualifier), { idx, val -> val["module"] })

    if len(imports)
      call add(filters, purescript#ide#utils#modulesFilter(imports))
    else
      " none of imported modules is qualified with a:qualifier
    endif
    let matcher = s:flexMatcher(a:ident)
  else
    if g:psc_ide_omnicompletion_filter_modules
      let imports = map(purescript#ide#import#listImports(currentModule), { n, m -> m.module })
      call extend(imports, [currentModule, "Prim"])
      call add(filters, purescript#ide#utils#modulesFilter(modules))
    endif
    let matcher = s:flexMatcher(a:ident)
  endif

  if type(modules) == v:t_list
    let filters = [purescript#ide#utils#modulesFilter(modules)]
  endif

  if empty(a:ident)
    let matcher = {}
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

" SET UP OMNICOMPLETION ------------------------------------------------------
fun! PSCIDEomni(findstart, base)
  if a:findstart
    return s:completeFn(a:findstart, a:base, function("s:omniCommand"), v:true)
  else
    let results = s:completeFn(a:findstart, a:base, function("s:omniCommand"), v:true)
    if empty(results)
      let results = PSCIDEcomplete(a:findstart, a:base)
    endif
    return results
  endif
endfun

" SET UP USERCOMPLETION ------------------------------------------------------
fun! PSCIDEcomplete(findstart, base)
  return s:completeFn(a:findstart, a:base, function("s:completeCommand"), v:true)
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
  let result = get(a:resp, "result", [])
  let filePadding = min([max(map(copy(result), { i, r -> type(r.definedAt) == v:t_dict && has_key(r.definedAt, "name") ? len(r.definedAt.name) : 0})) + 1, 30])
  let modulePadding = min([max(map(copy(result), { i, r -> type(r.module) == v:t_string ? len(r.module) : 0})) + 1, 30])
  for res in result
    let llentry = {}
    if (has_key(res, "definedAt") && type(res.definedAt) == v:t_dict)
      let llentry.lnum = res.definedAt.start[0]
      let llentry.col = res.definedAt.start[1]
      let bufnr = bufnr(res.definedAt.name)
      if bufnr != -1
	let llentry.bufnr = bufnr
      endif
      let llentry.filename = printf("%-" . filePadding . "s", res.definedAt.name)
    endif
    let module = get(res, "module", "")
    if empty(module)
      let module = ""
    endif
    let llentry.module = printf("%-" . modulePadding . "s", module)
    let llentry.text = printf("%s %s", res.identifier, res.type)
    call add(llist, llentry)
  endfor
  " echom json_encode(a:resp)
  call setloclist(0, llist)
  call setloclist(0, [], 'a', {'title': 'PureScript Search'})
  lopen
endfun

" ADD IMPORTS  --------------------------------------------------------------
fun! PSCIDEimportModule(module)
  let args = filter(split(a:module, '\s\+'), { idx, p -> p != ' ' && p != 'as' })
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

  call purescript#ide#utils#update()

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

  " trigger PSCIDErebuild
  call purescript#ide#utils#update()
  call PSCIDErebuild(v:true, "", function("PSCIDEerrors"))
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

  let filePadding = min([max(map(copy(a:llist), { i, r -> type(r.filename) == v:t_string ? len(r.filename) : 0})) + 1, 30])
  let modulePadding = min([max(map(copy(a:llist), { i, r -> type(r.module) == v:t_string ? len(r.module) : 0})) + 1, 30])

  let qfList = []
  for e in a:llist
    if e.bufnr != -1
      let text = split(e.text, '\n')
      call add(
	    \ qfList
	    \ , { "bufnr": e.bufnr
	    \   , "filename": printf("%-" . filePadding . "s", e.filename)
	    \	, "module": empty(e.module) ? e.module : printf("%-" . modulePadding . "s", e.module)
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
  let lnumend = has_key(a:e, "position") && type(a:e.position) == v:t_dict
  \ ? a:e.position.endLine : 1
  let col = has_key(a:e, "position") && type(a:e.position) == v:t_dict
	\ ? a:e.position.startColumn : 1
  let colend = has_key(a:e, "position") && type(a:e.position) == v:t_dict
  \ ? a:e.position.endColumn : 1
  let module = get(a:e, "moduleName", "")
  if empty(module)
    let module = ""
  endif
  return  { "filename": a:filename
	\ , "module": module
	\ , "bufnr": bufnr(a:filename)
	\ , "lnum": lnum
	\ , "lnumend": lnumend
	\ , "col": col
	\ , "colend": colend
	\ , "text": a:e.message
	\ , "type": type
	\ }
endfunction

function! s:addSuggestion(suggestions, e)
   let a:suggestions[a:e.filename . "|" . string(a:e.position.startLine)] = a:e.suggestion
endfunction

fun! PSCIDEgetKeyword()
  let isk = &l:isk
  setl isk+=.,48-57,<,>,$,#,+,-,*,/,%,',&,=,!,:,124,~,?,^
  let keyword = expand("<cword>")
  let &l:isk = isk
  return keyword
endfun

" AUTOSTART ------------------------------------------------------------------
call s:autoStart()
