" Find root folder ----------------------------------------------------
function! purescript#ide#utils#findRoot()
  let pscPackage = findfile("psc-package.json", fnameescape(expand("%:p:h")).";")
  if !empty(pscPackage)
    return fnamemodify(pscPackage, ":p:h")
  else
    let bower = findfile("bower.json", fnameescape(expand("%:p:h")).";")
    if !empty(bower)
      return fnamemodify(bower, ":p:h")
    else
      let spago = findfile("spago.dhall", fnameescape(expand("%:p:h")).";")
      if !empty(spago)
        return fnamemodify(spago, ":p:h")
      else
        return ""
      endif
    endif
  endfor
endfunction

fun! purescript#ide#utils#toString(msg)
  if type(a:msg) == v:t_string
    return a:msg
  elseif type(a:msg) == v:t_list
    return join(map(copy(a:msg), { idx, msg -> purescript#ide#utils#toString(msg) }), " ")
  elseif type(a:msg) == v:t_dict
    let msg = {}
    for key in a:msg
      let msg[key] = purescript#ide#utils#toString(a:msg[key])
    endfor
    return string(msg)
  else
    return string(a:msg)
  endif
endfun

fun! purescript#ide#utils#error(msg, ...)
  let title = a:0 > 0 && a:1 ? "purs ide server: " : "purs ide: "
  echohl ErrorMsg
  echom title . join(split(a:msg, '\n'), ' ')
  echohl Normal
endfun

fun! purescript#ide#utils#warn(msg, ...)
  let title = a:0 > 0 && a:1 ? "purs ide server: " : "purs ide: "
  echohl WarningMsg
  echom title . join(split(a:msg, '\n'), ' ')
  echohl Normal
endfun

fun! purescript#ide#utils#log(msg, ...)
  let title = a:0 > 0 && a:1 ? "purs ide server: " : "purs ide: "
  echom title . join(split(a:msg, '\n'), ' ')
endfun

fun! purescript#ide#utils#debug(str, level)
  if g:psc_ide_log_level >= a:level
    echom a:str
  endif
endfun

fun! purescript#ide#utils#update()
  let ei=&ei
  set ei=all
  update
  let &ei=ei
endfun

fun! purescript#ide#utils#modulesFilter(modules)
  return { "filter": "modules", "params": { "modules": a:modules } }
endfun

" Display choices from a list of dicts for the user to select from with
" alphanumerals as shortcuts
function! purescript#ide#utils#pickOption(message, options, labelKey)
  let displayOptions = copy(a:options)
  call map(displayOptions, '(v:key > 9 ? nr2char(v:key + 55) : v:key) . " " . v:val[a:labelKey]')
  let choice = confirm(a:message, join(displayOptions, "\n"))
  if choice
    return {'picked': v:true, 'option': a:options[choice - 1]}
  else
    return {'picked': v:false, 'option': v:null}
  endif
endfunction

fun! purescript#ide#utils#splitQualifier(ident)
    if match(a:ident, '\.') != -1
      let str_ = split(a:ident, '\.', v:true)
      let qualifier = join(str_[0:len(str_)-2], ".")
      let ident= str_[len(str_) - 1]
    else
      let ident = a:ident
      let qualifier = ""
    endif
    return [ident, qualifier]
endfun

function! purescript#ide#utils#currentModule()
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
