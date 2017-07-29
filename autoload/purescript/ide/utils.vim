" Find root folder ----------------------------------------------------
function! purescript#ide#utils#findRoot()
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

