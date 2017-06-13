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
    echo a:msg
  elseif type(a:msg) == v:t_list
    return join(map(copy(a:msg), { idx, msg -> s:toString(msg) }), " ")
  elseif type(a:msg) == v:t_dict
    let msg = {}
    for key in a:msg
      msg[key] = s:toString(a:msg[key])
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
