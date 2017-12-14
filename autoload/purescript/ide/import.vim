fun! s:FilterPrelude(respResults)
  call filter(a:respResults, { idx, r -> index(g:psc_ide_prelude, r.module) == -1 })
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

function! purescript#ide#import#listImports(module, ...)
  if a:0 >= 1
    let qualifier = a:1
  else
    let qualifier = ""
  endif

  if a:0 >= 2
    let ident = a:2
  else
    let ident = ""
  endif

  call purescript#ide#utils#update()
  let filename = expand("%:p")
  let resp = purescript#ide#callSync(
	\ {'command': 'list', 'params': {'type': 'import', 'file': filename}},
	\ 'Failed to get imports for: ' . a:module,
	\ 0
	\ )
  call purescript#ide#utils#debug("PSCIDE purescript#ide#import#listImports result: " . string(resp), 3)

  " Only need module names right now, so pluck just those.
  if type(resp) == v:t_dict && resp['resultType'] ==# 'success'

    " psc-ide >=0.11 returns imports on 'imports' property.
    if type(resp.result) == v:t_list
      let results = resp.result
    else
      let results = resp.result.imports
    endif
    if !empty(qualifier)
      call filter(results, { idx, val -> get(val, "qualifier", "") == qualifier })
    end
    if !empty(ident)
      call filter(results, {idx, val ->  get(val, "importType", "") == "explicit" && has_key(val, "identifiers") ? index(val.identifiers, ident) != -1 : v:true})
    endif
    return results
  else
    call purescript#ide#handlePursError(resp)
    return []
  endif
endfunction


" Return line number of last import line (including blank lines).
"
" It will fail to find the proper line on
" ```
" import Prelude
"   (Unit
" , bind
" , const)
" ```
"
" But it will run fine if all the lines are indented.
fun! purescript#ide#import#lastImportLine(lines)
  let idx = len(a:lines) + 1
  let import = v:false
  for line in reverse(copy(a:lines))
    let idx -= 1
    if line =~# '^import\>'
      break
    endif
  endfor
  let nLine = get(a:lines, idx+1, "-")
  while nLine =~# '^\s*$' || nLine =~# '^\s\+'
    let idx += 1
    let nLine = get(a:lines, idx, "-")
  endwhile
  return idx
endfun

" Import identifier callback
" resp	  - server response
" ident	  - identifier 
" view	  - win view (as returned by `winsaveview()`)
" lines	  - number of lines in the buffer
" silent  - do not output any messages
" rebuild - rebuild flag
" ignoreMultiple
"	  - ignore when received multiple results from the server
" fixCol  - when invoked from `CompleteDone` autocommand, we need to add one
"	    to column.  This works when one hits space to chose a completion
"	    result, while it moves the cursor when <C-E> is used (better than
"	    the other way around).
function! s:callback(resp, ident, view, lines, silent, rebuild, ignoreMultiple, fixCol) 
  if type(a:resp) != v:t_dict || get(a:resp, "resultType", "error") !=# "success"
    if !a:silent && type(a:resp) == v:t_dict
	return purescript#ide#utils#log(a:resp["result"])
    else
      return
    endif
  endif

  if type(a:resp.result) == v:t_list && type(get(a:resp.result, 0, v:null)) == v:t_dict
  " if v:false && type(a:resp.result) == v:t_list
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
      if !a:ignoreMultiple
	let choice = purescript#ide#utils#pickOption("Multiple possibilities to import " . a:ident, results, "module")
      else
	return
      endif
    endif
    if choice.picked == v:true
      call purescript#ide#import#identifier(a:ident, choice.option.module)
    endif
    return
  endif

  let bLast = purescript#ide#import#lastImportLine(getline(1, '$'))
  let nLast = purescript#ide#import#lastImportLine(a:resp.result)
  exe "1," . bLast . "d_"
  call append(0, a:resp.result[0:nLast - 1])

  if mode() == 'i'
    call feedkeys("\<C-g>u", "n")
  endif
  let a:view.topline = a:view.topline + line("$") - a:lines
  let a:view.lnum = a:view.lnum + line("$") - a:lines
  if a:fixCol
    let a:view.col = a:view.col + 1
  endif
  call winrestview(a:view)
  if mode() == 'i'
    call feedkeys("\<C-g>u", "n")
  endif

  " trigger PSCIDErebuild
  if a:rebuild
    call purescript#ide#utils#update()
    call PSCIDErebuild(v:true, "", function("PSCIDEerrors"))
  endif
endfunction


" import identifier
" a:ident	    - the identifier (might be qualified)
" a:module    - empty string or name of the module to search in
"
" Explicit a:module is used when there were multiple choices, to limit the
" choice, where it must be respected and also in
" `purescript#ide#imports#completeDone` where it might be modified.
function! purescript#ide#import#identifier(ident, module, ...)

  call purescript#ide#utils#debug('PSCIDEimportIdentifier', 3)
  call purescript#ide#utils#debug('ident: ' . a:ident, 3)

  if a:0 >= 1
    let silent = a:1
  else
    let silent = v:false
  endif

  if a:0 >= 2
    let rebuild = a:2
  else
    let rebuild = v:true
  endif

  if a:0 >= 3
    let ignoreMultiple = a:3
  else
    let ignoreMultiple = v:false
  endif

  if a:0 >= 4
    let fixCol = a:4
  else
    let fixCol = v:false
  endif

  if (a:ident == "")
    return
  endif

  if getline(".") =~ '^\s*import\>'
    return
  endif

  let file = fnamemodify(bufname(""), ":p")
  let [ident, qualifier] = purescript#ide#utils#splitQualifier(a:ident)
  if !empty(a:module)
    " When running through CompleteDone we need to preserve a:module.  But
    " also the module might not be imported yet with qualificaton or the
    " qualified module was already imported in which case we'd limit the list
    " of modules to `a:module` anyway.
    let filters = [purescript#ide#utils#modulesFilter([a:module])]
    let importCommand = {
	  \ "importCommand": "addImport",
	  \ "identifier": ident
	  \ }
  elseif empty(qualifier)
    let filters = []
    let importCommand = {
	  \ "importCommand": "addImport",
	  \ "identifier": ident
	  \ }
  else
    " Otherwise filter imported modules by qualification
    let currentModule = purescript#ide#utils#currentModule()
    let imports = purescript#ide#import#listImports(currentModule, qualifier)
    let modules = map(copy(imports), {key, val -> val["module"]})
    if len(modules) > 0
      let filters = [purescript#ide#utils#modulesFilter(modules)]
    else
      let filters = []
    endif
    let importCommand = {
	  \ "importCommand": "addImport",
	  \ "qualifier": qualifier,
	  \ "identifier": ident
	  \ }
  endif

  let input = { 
        \ 'command': 'import' ,
        \ 'params': {
        \   'file': file, 
	\   'filters': filters,
        \   'importCommand': importCommand
        \ } }

  if !empty(qualifier)
    let input.params.importCommand.qualifier = qualifier
  endif

  let view = winsaveview()
  let lines = line("$")
  " updated the file
  call purescript#ide#utils#update()

  call purescript#ide#call(
	\ input,
	\ silent ? v:null : "Failed to import identifier " . a:ident, 
	\ 0,
	\ {resp -> s:callback(resp, a:ident, view, lines, silent, rebuild, ignoreMultiple, fixCol)},
	\ v:true
	\ )
endfunction

" Import identifiers on completion.  This differs from the import command in
" several ways:
"   - run in silent mode (do not disturb when a user is typing)
"   - do not rebuild when done
"   - ignore when there is no unique result
"   - add 1 to col after completion (see s:callback for explanation)
fun! purescript#ide#import#completeDone()
  if !g:psc_ide_import_on_completion
    return
  endif

  if !has_key(v:completed_item, "word")
    return
  endif

  let ident = v:completed_item["word"]
  let module = get(split(v:completed_item["info"]), 0, "")
  call purescript#ide#import#identifier(ident, module, v:true, v:false, v:true, v:true)
endfun
