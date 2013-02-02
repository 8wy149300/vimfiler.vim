"=============================================================================
" FILE: init.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 02 Feb 2013.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vimfiler')
let s:BM = s:V.import('Vim.BufferManager')
let s:manager = s:BM.new()  " creates new manager
call s:manager.config('opener', 'silent edit')
call s:manager.config('range', 'current')

function! vimfiler#init#_initialize_context(context) "{{{
  let default_context = {
    \ 'buffer_name' : 'default',
    \ 'no_quit' : 0,
    \ 'quit' : 0,
    \ 'toggle' : 0,
    \ 'create' : 0,
    \ 'simple' : 0,
    \ 'double' : 0,
    \ 'split' : 0,
    \ 'horizontal' : 0,
    \ 'winheight' : 0,
    \ 'winwidth' : 0,
    \ 'winminwidth' : 0,
    \ 'direction' : g:vimfiler_split_rule,
    \ 'auto_cd' : g:vimfiler_enable_auto_cd,
    \ 'explorer' : 0,
    \ 'reverse' : 0,
    \ 'project' : 0,
    \ 'vimfiler__prev_bufnr' : bufnr('%'),
    \ 'vimfiler__prev_winnr' : winbufnr('%'),
    \ 'vimfiler__winfixwidth' : &l:winfixwidth,
    \ 'vimfiler__winfixheight' : &l:winfixheight,
    \ }
  if get(a:context, 'explorer', 0)
    " Change default value.
    let default_context.buffer_name = 'explorer'
    let default_context.split = 1
    let default_context.toggle = 1
    let default_context.no_quit = 1
    let default_context.winwidth = 35
  endif
  let context = extend(default_context, a:context)

  if !has_key(context, 'profile_name')
    let context.profile_name = context.buffer_name
  endif

  return context
endfunction"}}}
function! vimfiler#init#_initialize_vimfiler_directory(directory, context) "{{{1
  " Set current directory.
  let current = vimfiler#util#substitute_path_separator(
        \ a:directory)
  let b:vimfiler.current_dir = current
  if b:vimfiler.current_dir !~ '[:/]$'
    let b:vimfiler.current_dir .= '/'
  endif
  let b:vimfiler.current_files = []
  let b:vimfiler.original_files = []

  let b:vimfiler.is_visible_dot_files = 0
  let b:vimfiler.simple = a:context.simple
  let b:vimfiler.directory_cursor_pos = {}
  let b:vimfiler.current_mask = ''
  let b:vimfiler.clipboard = {}

  let b:vimfiler.global_sort_type = g:vimfiler_sort_type
  let b:vimfiler.local_sort_type = g:vimfiler_sort_type
  let b:vimfiler.is_safe_mode = g:vimfiler_safe_mode_by_default
  let b:vimfiler.winwidth = winwidth(0)
  let b:vimfiler.another_vimfiler_bufnr = -1
  call vimfiler#set_current_vimfiler(b:vimfiler)

  call vimfiler#default_settings()
  call vimfiler#mappings#define_default_mappings(a:context)

  set filetype=vimfiler

  if a:context.double
    " Create another vimfiler.
    call vimfiler#mappings#create_another_vimfiler()
    wincmd p
  endif

  if a:context.winwidth != 0
    execute 'vertical resize' a:context.winwidth
  endif

  call vimfiler#force_redraw_all_vimfiler()
endfunction"}}}
function! vimfiler#init#_initialize_vimfiler_file(path, lines, dict) "{{{1
  " Set current directory.
  let b:vimfiler.current_path = a:path
  let b:vimfiler.current_file = a:dict

  " Clean up the screen.
  % delete _

  augroup vimfiler
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer>
          \ call vimfiler#handler#_event_handler('BufWriteCmd')
  augroup END

  call setline(1, a:lines)

  setlocal buftype=acwrite
  setlocal noswapfile

  " For filetype detect.
  execute 'doautocmd BufRead' fnamemodify(a:path[-1], ':t')

  let &fileencoding = get(a:dict, 'vimfiler__encoding', '')

  setlocal nomodified
endfunction"}}}

function! vimfiler#init#_start(path, ...) "{{{
  if vimfiler#util#is_cmdwin()
    call vimfiler#print_error(
          \ '[vimfiler] Command line buffer is detected!')
    call vimfiler#print_error(
          \ '[vimfiler] Please close command line buffer.')
    return
  endif

  let path = a:path
  if vimfiler#util#is_win_path(path)
    let path = vimfiler#util#substitute_path_separator(
          \ fnamemodify(vimfiler#util#expand(path), ':p'))
  endif

  let context = vimfiler#initialize_context(get(a:000, 0, {}))
  if &l:modified && !&l:hidden
    " Split automatically.
    let context.split = 1
  endif

  if context.toggle && !context.create
    if vimfiler#close(context.buffer_name)
      return
    endif
  endif

  if !context.create
    " Search vimfiler buffer.
    for bufnr in filter(insert(range(1, bufnr('$')), bufnr('%')),
          \ "bufloaded(v:val) &&
          \ getbufvar(v:val, '&filetype') ==# 'vimfiler'")
      let vimfiler = getbufvar(bufnr, 'vimfiler')
      if type(vimfiler) == type({})
            \ && vimfiler.context.profile_name ==# context.profile_name
            \ && (!exists('t:unite_buffer_dictionary')
            \      || has_key(t:unite_buffer_dictionary, bufnr))
        call vimfiler#init#_switch_vimfiler(bufnr, context, path)
        return
      endif

      unlet vimfiler
    endfor
  endif

  call s:create_vimfiler_buffer(path, context)
endfunction"}}}
function! vimfiler#init#_switch_vimfiler(bufnr, context, directory) "{{{
  let context = vimfiler#initialize_context(a:context)

  if context.split
    if context.horizontal || context.double
      execute context.direction 'new'
    else
      execute context.direction 'vnew'
    endif
  endif

  execute 'buffer' . a:bufnr
  call vimfiler#handler#_event_bufwin_enter(a:bufnr)

  " Set current directory.
  if a:directory != ''
    let directory = vimfiler#util#substitute_path_separator(
          \ a:directory)
    if directory =~ ':'
      " Parse path.
      let ret = vimfiler#parse_path(directory)
      let b:vimfiler.source = ret[0]
      let directory = join(ret[1:], ':')
    endif

    let b:vimfiler.current_dir = directory
    if b:vimfiler.current_dir !~ '/$'
      let b:vimfiler.current_dir .= '/'
    endif
  endif

  let b:vimfiler.context = extend(b:vimfiler.context, context)
  call vimfiler#set_current_vimfiler(b:vimfiler)

  if a:context.double
    " Create another vimfiler.
    call vimfiler#mappings#create_another_vimfiler()
    wincmd p
  endif

  call vimfiler#force_redraw_all_vimfiler()
endfunction"}}}
function! s:create_vimfiler_buffer(path, context) "{{{
  let path = a:path
  if path == ''
    " Use current directory.
    let path = vimfiler#util#substitute_path_separator(getcwd())
  endif

  if a:context.project
    let path = vimfiler#util#path2project_directory(path)
  endif

  if &l:modified && !&l:hidden
    " Split automatically.
    let a:context.split = 1
  endif

  " Create new buffer name.
  let prefix = vimfiler#util#is_windows() ?
        \ '[vimfiler] - ' : '*vimfiler* - '
  let prefix .= a:context.profile_name

  let postfix = vimfiler#init#_get_postfix(prefix, 1)

  let bufname = prefix . postfix

  " Set buffer_name.
  let a:context.profile_name = a:context.buffer_name
  let a:context.buffer_name = bufname

  if a:context.split
    if a:context.horizontal || a:context.double
      execute a:context.direction 'new'
    else
      execute a:context.direction 'vnew'
    endif
  endif

  " Save swapfile option.
  let swapfile_save = &swapfile
  set noswapfile

  try
    let ret = s:manager.open(bufname)
    " silent edit `=bufname`
    setlocal noswapfile
  finally
    let &swapfile = swapfile_save
  endtry

  if !ret.loaded
    call vimshell#echo_error(
          \ '[vimfiler] Failed to open Buffer "'. bufname .'".')
    return
  endif

  let a:context.path = path
  " echomsg path

  call vimfiler#handler#_event_handler('BufReadCmd', a:context)

  call vimfiler#handler#_event_bufwin_enter(bufnr('%'))
endfunction"}}}

function! vimfiler#init#_default_settings() "{{{
  call s:buffer_default_settings()

  " Set autocommands.
  augroup vimfiler "{{{
    autocmd BufEnter,WinEnter,BufWinEnter <buffer>
          \ call vimfiler#handler#_event_bufwin_enter(expand('<abuf>'))
    autocmd BufLeave,WinLeave,BufWinLeave <buffer>
          \ call vimfiler#handler#_event_bufwin_leave(expand('<abuf>'))
    autocmd VimResized <buffer>
          \ call vimfiler#redraw_all_vimfiler()
  augroup end"}}}
endfunction"}}}

function! s:buffer_default_settings() "{{{
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal noreadonly
  setlocal nowrap
  setlocal bufhidden=hide
  setlocal nolist
  setlocal foldcolumn=0
  setlocal nofoldenable
  setlocal nowrap
  setlocal nomodifiable
  setlocal nomodified
  if has('netbeans_intg') || has('sun_workshop')
    setlocal noautochdir
  endif
  if exists('&colorcolumn')
    setlocal colorcolumn=
  endif

  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=n
  endif

  if vimfiler#get_context().explorer
    setlocal nobuflisted
  endif
endfunction"}}}

function! vimfiler#init#_get_postfix(prefix, is_create) "{{{
  let buffers = get(a:000, 0, range(1, bufnr('$')))
  let buflist = vimfiler#util#sort_by(filter(map(buffers,
        \ 'bufname(v:val)'), 'stridx(v:val, a:prefix) >= 0'),
        \ "str2nr(matchstr(v:val, '\\d\\+$'))")
  if empty(buflist)
    return ''
  endif

  let num = matchstr(buflist[-1], '@\zs\d\+$')
  return num == '' && !a:is_create ? '' :
        \ '@' . (a:is_create ? (num + 1) : num)
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
