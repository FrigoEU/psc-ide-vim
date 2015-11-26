if !has('python') && !has('python3')
  echo 'tern requires python support'
  finish
endif

" Get current working directory of psc-ide-server
command! PSCcwd call PSCcwd()
function! PSCcwd()
  let input = {'command': 'cwd'}
  let resp = system("psc-ide -p 4242", s:jsonEncode(input))
  let decoded = s:jsonDecode(resp)
  echom decoded["result"]
endfunction

" Load module of current buffer + its dependencies into psc-ide-server
command! PSCload call PSCload()
function! PSCload()
  let firstl = getline(1)
  let matches = matchlist(firstl, 'module\s\(\S*\)\s')

  if (len(matches) == 0)
    echom "No valid module declaration found"
    return
  endif

  let module = matches[1]
  let input = {'command': 'load', 'params': {'modules': [], 'dependencies': [module]}}

  let resp = system("psc-ide -p 4242", s:jsonEncode(input))
  let decoded = s:jsonDecode(resp)

  if (decoded['resultType'] ==# "success")
    echom decoded['result']
  else
    echom "Failed to load module: " . module
  endif
endfunction

" Get type of word under cursor
command! PSCtype call PSCtype()
function! PSCtype()
  let identifier = s:GetWordUnderCursor()
  let input = {'command': 'type', 'params': {'search': identifier, 'filters': []}}

  silent PSCload
  let resp = system("psc-ide -p 4242", s:jsonEncode(input))
  let decoded = s:jsonDecode(resp)

  if decoded['resultType'] ==# 'success' && len(decoded['result']) > 0
    echom s:format(decoded['result'][0])
  else
    echom 'Failed to get type info for: ' . identifier
  endif
endfunction

aug PSC
  au!
  au BufNewFile,BufRead *.purs setlocal omnifunc=PSComni
aug PSC
doau PSC BufRead

function! PSComni(findstart,base)
  let col   = col(".")
  let line  = getline(".")

  " search backwards for start of identifier (iskeyword pattern)
  let start = col
  while start>0 && (line[start-2] =~ "\\k" || line[start-2] =~ "\\.")
    let start -= 1
  endwhile

  if a:findstart 
    "Looking for the start of the identifier that we want to complete
    return start-1
  else
    echom "completing second round: " . a:base

    let entries = PSCGetCompletions(a:base)

    let result = []
    if type(entries)==type([])
      for entry in entries
        if entry['identifier'] =~ '^'.a:base
          call add(result, {'word': entry['identifier'], 'menu': s:StripNewlines(entry['type'])
                          \,'info': entry['module'] . "." . entry['identifier']})
        endif
      endfor
    endif
    "for r in result
      "echom s:jsonEncode(r)
    "endfor
    return result
  endif
endfunction

command! PSCcomplete call PSCGetCompletions(expand(<cword>))
"returns list of {module, identifier, type}
function! PSCGetCompletions(s)
  let input = {'command': 'complete', 'params': {'filters': [s:prefixFilter(a:s)], 'matcher': s:flexMatcher(a:s)}}

  silent PSCload
  let resp = system("psc-ide -p 4242", s:jsonEncode(input))
  let decoded = s:jsonDecode(resp)

  if decoded['resultType'] ==# 'success'
    return decoded['result']
  else
    echom 'Failed to get completions for: ' . a:s
  endif
endfunction

function! s:prefixFilter(s) 
  return {"filter": "prefix", "params": { "search": a:s } }
endfunction

function! s:flexMatcher(s)
  return {"matcher": "flex", "params": {"search": a:s} }
endfunction

function! s:format(record)
  return s:CleanEnd(s:StripNewlines(a:record['module']) . '.' . s:StripNewlines(a:record['identifier']) . ' :: ' . s:StripNewlines(a:record['type']))
endfunction

"------- Utility functions -----------------------------
function! s:StripNewlines(s)
  return substitute(a:s, '\s*\n\s*', ' ', 'g')
endfunction

function! s:CleanEnd(s)
  return substitute(a:s, '[\n\s]$', '', 'g')
endfunction

function! s:GetWordUnderCursor()
  return expand("<cword>")
endfunction

" Vim was ahead of its time :-) It spoke JSON before the Web discovered it -
" Well almost.
" Vim does not know about:
" true,false,null
" 
" Thus those values are represented as Vim functions.
"
" Because it can parse JSON natively when assigning true, false, null to
" values this is probably the fastest way to interface with external tools.
" The default implementation assigns:
" true  -> 1 (=vim value for true)
" false -> 0 (=vim value for false)
" null  -> 0 (=vims return value for procedures which is semantically
" similar to null - Yes, this is an arbitrary choice)
fun! s:jsonNULL()
  " return function("s:jsonNULL")
  return {'json_special_value': 'null'}
endf
fun! s:jsonTrue()
  " return function("s:jsonTrue")
  return {'json_special_value': 'true'}
endf
fun! s:jsonFalse()
  " return function("s:jsonFalse")
  return {'json_special_value': 'false'}
endf
fun! s:jsonToJSONBool(i)
  return  a:i ? s:jsonTrue() : s:jsonFalse()
endf

" optional arg: if true then append \n to , of top level dict
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

" if you want s:jsonEncode(s:jsonDecode(str)) == str
" then you have to assign true to s:jsonTrue() etc.
" I don't have a use case so I use Vim encoding

fun! s:jsonDecode(s)
  let true = 1
  let false = 0
  let null = 0
  return eval(s:CleanEnd(a:s))
endf

fun! s:jsonDecodePreserve(s)
  let true = s:jsonTrue()
  let false = s:jsonFalse()
  let null = s:jsonNULL()
  return eval(s:CleanEnd(a:s))
endf

"-- INIT ------------------------------------------------------

let s:plug = expand("<sfile>:p:h:h")
let s:script = s:plug . '/script/pscide.py'
if has('python')
  execute 'pyfile ' . fnameescape(s:script)
elseif has('python3')
  execute 'py3file ' . fnameescape(s:script)
endif

if has('python')
  python pscide_findServer()
elseif has('python3')
  python3 pscide_findServer()
endif


augroup PscideShutDown
  autocmd VimLeavePre * call s:Shutdown()
augroup END

function! s:Shutdown()
  if has('python')
    py pscide_killServer()
  elseif has('python3')
    py3 pscide_killServer()
  endif
endfunction

