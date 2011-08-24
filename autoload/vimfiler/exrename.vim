"=============================================================================
" FILE: exrename.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 24 Aug 2011.
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

function! vimfiler#exrename#create_buffer(files)"{{{
  let l:vimfiler_save = deepcopy(b:vimfiler)
  let l:bufnr = bufnr('%')

  vsplit
  edit exrename
  highlight clear
  syntax clear

  setlocal buftype=acwrite
  let b:exrename = l:vimfiler_save
  let b:exrename.bufnr = l:bufnr

  lcd `=b:exrename.current_dir`

  nnoremap <buffer><silent> q    :<C-u>call <SID>exit()<CR>
  augroup exrename
    autocmd!
    autocmd BufWriteCmd <buffer> call s:do_rename()
    autocmd CursorMoved,CursorMovedI <buffer> call s:check_lines()
  augroup END

  setfiletype exrename

  syn match ExrenameModified '^.*$'
  hi def link ExrenameModified Todo
  hi def link ExrenameOriginal Normal

  " Clean up the screen.
  % delete _

  " Print files.
  let b:exrename.current_files = []
  let b:exrename.current_filenames = []
  for l:file in a:files
    let l:filename = l:file.vimfiler__filename
    if l:file.vimfiler__is_directory
      let l:filename .= '/'
    endif

    execute 'syn match ExrenameOriginal'
          \ string(printf('^\%%%dl%s$', line('$'), l:filename))
    call append('$', l:filename)
    call add(b:exrename.current_files, l:file)
    call add(b:exrename.current_filenames, l:filename)
  endfor

  1delete

  setlocal nomodified
endfunction"}}}
function! s:exit()"{{{
  let l:exrename_buf = bufnr('%')
  " Switch buffer.
  if winnr('$') != 1
    close
  else
    call s:custom_alternate_buffer()
  endif
  execute 'bdelete!' l:exrename_buf
endfunction"}}}
function! s:do_rename()"{{{
  if line('$') != len(b:exrename.current_filenames)
    echohl Error | echo 'Invalid rename buffer!' | echohl None
    return
  endif

  " Rename files.
  let l:linenr = 1
  while l:linenr <= line('$')
    let l:filename = b:exrename.current_filenames[l:linenr - 1]
    if l:filename !=# getline(l:linenr)
      let l:file = b:exrename.current_files[l:linenr - 1]
      call unite#mappings#do_action('vimfiler__rename', [l:file],
            \ {'action__filename' : getline(l:linenr)})
    endif

    let l:linenr += 1
  endwhile

  setlocal nomodified
  call s:exit()

  call vimfiler#force_redraw_all_vimfiler()
endfunction"}}}

function! s:check_lines()"{{{
  if line('$') != len(b:exrename.current_filenames)
    echohl Error | echo 'Invalid rename buffer!' | echohl None
    return
  endif
endfunction"}}}

function! s:custom_alternate_buffer()"{{{
  if bufnr('%') != bufnr('#') && buflisted(bufnr('#'))
    buffer #
  else
    let l:cnt = 0
    let l:pos = 1
    let l:current = 0
    while l:pos <= bufnr('$')
      if buflisted(l:pos)
        if l:pos == bufnr('%')
          let l:current = l:cnt
        endif

        let l:cnt += 1
      endif

      let l:pos += 1
    endwhile

    if l:current > l:cnt / 2
      bprevious
    else
      bnext
    endif
  endif
endfunction"}}}

" vim: foldmethod=marker
