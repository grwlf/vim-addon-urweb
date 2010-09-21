exec scriptmanager#DefineAndBind('s:c','s:vim_addon_urweb','{}')
" writeable directory so that we can tag the .ur and .urs library files
let s:c['urweb_compiler_sources_dir'] = get(s:c,'urweb_compiler_sources_dir', g:vim_script_manager['plugin_root_dir'].'/urweb-compiler-sources')

" checkout main .urp library files so that they can be tagged
fun! urweb#CheckoutUrwebSources()
  let srcdir = s:c['urweb_compiler_sources_dir']
  if !isdirectory(srcdir)
    if input('trying to checkout urweb compiler sources into '.srcdir.'. ok ? [y/n]') == 'y'
      call mkdir(srcdir.'/archive','p')
      " checking out std ony would suffice. disk is cheap today..
      call scriptmanager2#Checkout(srcdir, {'url': 'http://www.impredicative.com/ur/urweb-20100603.tgz'})
    else
      return ""
    endif
  endif
  return srcdir
endf

fun! urweb#SetUrwebProjectFile(...)
  let old = exists('g:urweb_projectfile') ? g:urweb_projectfile : ""
  if a:0 > 0
    let new_=a:1
  elseif !exists('g:urweb_projectfile')
    let new_=input('specify your .urp file file: ','','customlist,urweb#UrwebProjectFileCompletion')
  else
    new_ = g:urweb_projectfile
  endif
  if new_ != old
    let g:urweb_projectfile=new_
    call urweb#ProjectFileChanged()
  endif
  return g:urweb_projectfile
endf

fun! urweb#UrwebProjectFileCompletion(ArgLead, CmdLine, CursorPos)
  return filter(split(glob("*.urp"), "\n"),'v:val =~'.string(a:ArgLead))
endf

fun! urweb#ProjectFileChanged()
  " tag lib
  let urwebSources = urweb#CheckoutUrwebSources()
  if urwebSources != ""
    call urweb#TagAndAdd(urwebSources.'/lib','**/*.ur*')
  endif
endf

" TODO refactor, shared by vim-addon-ocaml ?
fun! urweb#TagAndAdd(d, pat)
  call vcs_checkouts#ExecIndir([{'d': a:d, 'c': g:vim_haxe_ctags_command_recursive.' '.a:pat}])
  exec 'set tags+='.substitute(a:d,',','\\\\,','g').'/tags'
endf


function! urweb#BcAc()
  let pos = col('.') -1
  let line = getline('.')
  return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
endfunction

" A)
" name:type completion
" type can be string->string or such (is based on tags and only takes into " account the first line)
"
" assumens your tags have been generated with ctags (which puts uses regex as a cmd)
fun! urweb#UrComplete(findstart, base)
  if a:findstart
    let [bc,ac] = urweb#BcAc()
    let s:match_text = matchstr(bc, '\zs[^()[\]{}\t ]*$')
    let s:start = len(bc)-len(s:match_text)
    return s:start
  else
    let patterns = vim_addon_completion#AdditionalCompletionMatchPatterns(a:base
        \ , "ocaml_completion", { 'match_beginning_of_string': 1})
    let additional_regex = get(patterns, 'vim_regex', "")


    let ar = split(a:base,":",1) + [""]
    for t in taglist('^'.ar[0]) + (ar[0] == "" ? [] : taglist('^'.additional_regex))
      " assuming t.cmd is a regex
      " TODO: take into account if function spawns multiple lines!
      let type = matchstr(t.cmd, '[^=:]*[=:]*\zs.*\ze/')
      if ar[1] != '' && type !~ ar[1] | continue | endif
      " should filter tables, views, class ? For now they occur much less
      " often, so they don't hurt much
      let info = t.kind.' '.type
      call complete_add({'word': t.name, 'menu': info, 'info': info })
    endfor
    return []
  endif
endf
