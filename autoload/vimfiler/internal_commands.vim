"=============================================================================
" FILE: internal_commands.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 03 May 2010
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

function! vimfiler#internal_commands#mv(dest_dir, src_files)"{{{
  for l:src in a:src_files
    call rename(l:src, a:dest_dir . l:src)
  endfor
endfunction"}}}
function! vimfiler#internal_commands#cp(dest_dir, src_files)"{{{
  call s:external('copy', a:dest_dir, a:src_files)
endfunction"}}}
function! vimfiler#internal_commands#rm(files)"{{{
  for l:file in a:files
    if isdirectory(l:file)
      call s:external('delete', '', [l:file])
    else
      call delete(l:file)
    endif
  endfor
endfunction"}}}
function! s:external(command, dest_dir, src_files)"{{{
  let l:command_line = g:vimfiler_external_{a:command}_command

  if l:command_line =~# '$src\>'
    for l:src in a:src_files
      let l:command_line = g:vimfiler_external_{a:command}_command
      if isdirectory(l:src)
        let l:command_line = substitute(l:command_line, 
              \'\$dest$srcdir\>', '"'.a:dest_dir.l:src.'"', 'g') 
      else
        let l:command_line = substitute(l:command_line, 
              \'\$dest$srcdir\>', '"'.a:dest_dir.'"', 'g') 
      endif
      
      let l:command_line = substitute(l:command_line, 
            \'\$src\>', '"'.l:src.'"', 'g') 
      let l:command_line = substitute(l:command_line, 
            \'\$dest\>', '"'.a:dest_dir.'"', 'g')
      
      if vimfiler#iswin() && l:command_line =~? '^\%(xcopy\|rmdir\)\%(\.exe\)\? '
        let l:output = system(l:command_line)
        if &termencoding != '' && &termencoding != &encoding
          let l:output = iconv(l:output, &termencoding, &encoding)
        endif
      else
        let l:output = vimfiler#system(l:command_line)
      endif
      
      echon l:output
    endfor
  else
    let l:command_line = substitute(l:command_line, 
          \'\$srcs\>', join(map(a:src_files, '''"''.v:val.''"''')), 'g') 
    let l:command_line = substitute(l:command_line, 
          \'\$dest\>', '"'.a:dest_dir.'"', 'g')

    if vimfiler#iswin() && l:command_line =~? '^\%(xcopy\|rmdir\)\%(\.exe\)\? '
      let l:output = system(l:command_line)
      if &termencoding != '' && &termencoding != &encoding
        let l:output = iconv(l:output, &termencoding, &encoding)
      endif
    else
      let l:output = vimfiler#system(l:command_line)
    endif
    
    echon l:output
  endif
endfunction"}}}

function! vimfiler#internal_commands#cd(dir)"{{{
  if a:dir == '..'
    if b:vimfiler.current_dir =~ '^\a\+:$\|^/$'
      " Select drive.
      call vimfiler#mappings#move_to_drive()
      return
    endif

    let l:dir = simplify(b:vimfiler.current_dir . '/' . a:dir)
  elseif a:dir == '/'
    " Root.
    let l:dir = vimfiler#iswin() ? 
          \matchstr(fnamemodify(b:vimfiler.current_dir, ':p'), '^\a\+:[/\\]') : a:dir
  elseif a:dir == '~'
    " Home.
    let l:dir = expand('~')
  elseif (vimfiler#iswin() && a:dir =~ '^\a\+:[/\\]\|^\a\+:$')
        \ || (!vimfiler#iswin() && a:dir =~ '^/')
    let l:dir = a:dir
  else
    " Relative path.
    let l:dir = simplify(b:vimfiler.current_dir . '/' . a:dir)
  endif

  if !isdirectory(l:dir)
    " Ignore.
    return
  endif

  lcd `=l:dir`
  if l:dir[-1:] == '/' || l:dir[-1:] == '\'
    " Delete last '/'.
    let l:dir = l:dir[: -2]
  endif

  " Save current pos.
  let b:vimfiler.directory_cursor_pos[b:vimfiler.current_dir] = getpos('.')
  let b:vimfiler.current_dir = l:dir

  " Redraw.
  call vimfiler#force_redraw_screen()

  if has_key(b:vimfiler.directory_cursor_pos, l:dir)
    " Restore cursor pos.
    call setpos('.', b:vimfiler.directory_cursor_pos[l:dir])
  endif
endfunction"}}}
function! vimfiler#internal_commands#open(filename)"{{{
  if &termencoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:filename = iconv(a:filename, &encoding, &termencoding)
  else
    let l:filename = a:filename
  endif

  " Detect desktop environment.
  if vimfiler#iswin()
    if executable('cmdproxy.exe') && exists('*vimproc#system')
      " Use vimproc.
      call vimproc#system(printf('cmdproxy /C "start \"\" \"%s\""', a:filename))
    else
      execute printf('silent ! start "" "%s"', a:filename)
    endif
  elseif executable('open')
    call system('open ''' . a:filename . ''' &')
  elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
    " KDE.
    call system('kfmclient exec ''' . a:filename . ''' &')
  elseif exists('$GNOME_DESKTOP_SESSION_ID')
    " GNOME.
    call system('gnome-open ''' . a:filename . ''' &')
  elseif executable('exo-open')
    " Xfce.
    call system('exo-open ''' . a:filename . ''' &')
  else
    throw 'Not supported.'
  endif
endfunction"}}}
function! vimfiler#internal_commands#gexe(filename)"{{{
  if vimfiler#iswin()
    if a:filename !=# 'gvim' && executable('cmdproxy.exe') && vimfiler#is_vimproc()
      " Use vimproc.
      let l:commands = split(a:filename)
      call vimproc#system(printf('cmdproxy /C "start \"\" \"%s\" %s"', l:commands[0], join(l:commands[1:])))
    else
      execute 'silent ! start ' a:filename
    endif
  else
    " For *nix.

    " Background execute.
    call system(a:filename . '&')
  endif
endfunction"}}}
function! vimfiler#internal_commands#split()"{{{
  if g:vimfiler_split_command == 'split_nicely'
    " Split nicely.
    if winheight(0) > &winheight
      split
    else
      vsplit
    endif
  else
    execute g:vimfiler_split_command
  endif
endfunction"}}}
function! vimfiler#internal_commands#edit(filename)"{{{
  try
    if g:vimfiler_edit_command == 'edit_nicely'
      if winheight(0) > &winheight
        new `=a:filename`
      else
        vnew `=a:filename`
      endif
    else
      execute g:vimfiler_edit_command a:filename
    endif
  catch
    echohl Error | echomsg v:errmsg | echohl None
  endtry
endfunction"}}}
function! vimfiler#internal_commands#pedit(filename)"{{{
  try
    execute g:vimfiler_pedit_command a:filename
  catch
    echohl Error | echomsg v:errmsg | echohl None
  endtry
endfunction"}}}

" vim: foldmethod=marker
