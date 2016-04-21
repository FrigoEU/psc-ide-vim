"============================================================================
"File:        pscide.vim
"Description: Syntax checking plugin for purescript through psc-ide/pulp build
"Maintainer:  Simon Van Casteren (https://github.com/FrigoEU)
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"============================================================================

if exists('g:loaded_syntastic_purescript_pscide_checker')
    finish
endif
" g:psc_ide_syntastic_mode:
"   0 = off
"   1 = single module mode (via psc-ide rebuild)
"   2 = full build mode (via pulp)
if !exists('g:psc_ide_syntastic_mode')
  let g:psc_ide_syntastic_mode = 1
endif
if g:psc_ide_syntastic_mode == 0
  finish
endif

let g:loaded_syntastic_purescript_pscide_checker = 1

let s:save_cpo = &cpo
set cpo&vim

function! SyntaxCheckers_purescript_pscide_IsAvailable() dict
  if (g:psc_ide_syntastic_mode == 1)
    let version_output = syntastic#util#system('psc --version')
    let parsed_ver = syntastic#util#parseVersion(version_output)
    return syntastic#util#versionIsAtLeast(parsed_ver, [0, 8, 5, 0])
  endif
  if (g:psc_ide_syntastic_mode == 2)
    return executable('pulp')
  endif
endfunction

function! SyntaxCheckers_purescript_pscide_GetLocList() dict
  if g:psc_ide_syntastic_mode == 1
    " Mode one doesn't use an executable, so we just do something trivial like
    " echo in makeprg and do the real work in Preprocess
    let loclist = SyntasticMake({
        \ 'makeprg': self.makeprgBuild({'exe': 'echo', 'args': 'a'}), 
        \ 'errorformat': '%t:%f:%l:%c:%m',
        \ 'Preprocess': function('PSCIDErebuild') })
  endif

  if g:psc_ide_syntastic_mode == 2
    let loclist = SyntasticMake({
        \ 'makeprg': self.makeprgBuild({ 'fname': ''
        \                              , 'exe': 'pulp'
        \                              , 'args': 'build --no-psa --json-errors' }),
        \ 'errorformat': '%t:%f:%l:%c:%m',
        \ 'Preprocess': function('ParsePulp') })
  endif

  for e in loclist
    if e['type'] == 'F'
      let e['type'] = 'E'
      let e['subtype'] = 'Style'
    endif
    if e['type'] == 'V'
      let e['type'] = 'W'
      let e['subtype'] = 'Style'
    endif
  endfor

  return loclist
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'purescript',
    \ 'name': 'pscide'})

let &cpo = s:save_cpo
unlet s:save_cpo

function! s:error(str)
  if exists('syntastic#log#error')
    let logger = function('syntastic#log#error')
  elseif exists('neomake#utils#ErrorMessage')
    let logger = function('neomake#utils#ErrorMessage')
  endif
  echom a:str
  if exists("logger")
    call logger(a:str)
  endif
endfunction

function! ParsePulp(lines)
  let str = join(a:lines, " ")
  let g:psc_ide_suggestions = {}

  "We need at least {"warnings":[],"errors":[]}
   if len(str) < 20 || str !~# '{' || str !~# '}'
     return []
   endif

  let matched = matchlist(str, '{.*}')

  if len(matched) > 0
    let decoded = PscIdeDecodeJson(matched[0])
  else
    call s:error('checker purescript/pscide: unrecognized error format 1: ' . str)
    return []
  endif

  if type(decoded) == type({}) && type(decoded["warnings"]) == type([]) && type(decoded["errors"])
    let res = ParsePscJsonOutput(decoded["errors"], decoded["warnings"])
    if (res.error != "")
      call s:error(res.error)
    endif
    let g:psc_ide_suggestions = res.suggestions
    return res.llist
  else
    call s:error('checker purescript/pscide: unrecognized error format 4: ' . str)
    return []
  endif
endfunction
