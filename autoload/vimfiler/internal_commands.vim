"=============================================================================
" FILE: internal_commands.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Aug 2011.
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

function! vimfiler#internal_commands#cd(dir, ...)"{{{
  let l:save_history = a:0 ? a:1 : 1
  let l:dir = vimfiler#util#substitute_path_separator(a:dir)

  if l:dir == '..'
    if b:vimfiler.current_dir =~ '^\a\+:[/\\]$\|^/$'
      " Ignore.
      return
    endif

    let l:dir = fnamemodify(substitute(b:vimfiler.current_dir, '[/\\]$', '', ''), ':h')
  elseif l:dir == '/'
    " Root.
    let l:dir = vimfiler#iswin() ?
          \matchstr(fnamemodify(b:vimfiler.current_dir, ':p'), '^\a\+:[/\\]') : l:dir
  elseif l:dir == '~'
    " Home.
    let l:dir = expand('~')
  elseif (vimfiler#iswin() && l:dir =~ '^//\|^\a\+:')
        \ || (!vimfiler#iswin() && l:dir =~ '^/')
      " Network drive or absolute path.
  else
    " Relative path.
    let l:dir = simplify(b:vimfiler.current_dir . l:dir)
  endif
  let l:dir = vimfiler#util#substitute_path_separator(l:dir)

  if vimfiler#iswin()
    let l:dir = vimfiler#resolve(l:dir)
  endif

  if !isdirectory(l:dir)
    " Ignore.
    call vimfiler#print_error('cd: "' . l:dir . '" is not a directory.')
    return
  endif

  if l:dir !~ '/$'
    let l:dir .= '/'
  endif

  " Save current pos.
  let l:save_pos = getpos('.')
  let b:vimfiler.directory_cursor_pos[b:vimfiler.current_dir] = 
        \ deepcopy(l:save_pos)
  let l:prev_dir = b:vimfiler.current_dir
  let b:vimfiler.current_dir = l:dir

  " Save changed directories.
  if l:save_history
    call add(b:vimfiler.directories_history, l:prev_dir)

    let l:max_save = g:vimfiler_max_directories_history > 0 ?
          \ g:vimfiler_max_directories_history : 10
    if len(b:vimfiler.directories_history) >= l:max_save
      " Get last l:max_save num elements.
      let b:vimfiler.directories_history =
            \ b:vimfiler.directories_history[-l:max_save :]
    endif
  endif

  " Redraw.
  call vimfiler#force_redraw_screen()

  " Restore cursor pos.
  let l:save_pos[1] = 3
  call setpos('.', (has_key(b:vimfiler.directory_cursor_pos, l:dir) ?
        \ b:vimfiler.directory_cursor_pos[l:dir] : l:save_pos))
  normal! zz
endfunction"}}}
function! vimfiler#internal_commands#gexe(filename)"{{{
  if !exists('*vimproc#system_gui')
    echoerr 'vimproc#system_gui() is not found. Please install vimproc Ver.5.2 or later.'
    return
  endif

  let l:current_dir = getcwd()
  call vimfiler#cd(b:vimfiler.current_dir)
  call vimproc#system_gui(a:filename)
  call vimfiler#cd(l:current_dir)
endfunction"}}}

" vim: foldmethod=marker
