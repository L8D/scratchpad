nnoremap <leader>~ gg:set nofoldenable<CR>:let @z="\n\n"<cr>"zP"_dip"zP:let @z="# {{{\n\n# }}}"<cr>"zP:set foldenable<CR>zOji
vnoremap <leader>~ dgg:set nofoldenable<CR>:let @z="\n\n"<cr>"zPdip"zP:let @z="# {{{\n\n# }}}"<cr>"zP:set foldenable<CR>zOji
nnoremap <leader>O gg:let @z="\n"<cr>"zP"_dip"zPO

nnoremap <leader>P gg:let @z="\n"<CR>"zP"_dipV"_d"_dip
inoremap <S-CR> <C-G>u<Esc>Vy:let @z=trim(system(@"))<CR>V"zpgv
nnoremap ~! Vy:let @z=trim(system(@"))<CR>V"zpgv
nnoremap ~~ :call <SID>RunCurrentLine(0)<CR>
vnoremap ~~ "0y:call <SID>RunVisualSelection(0)<CR>
nnoremap ~<Space> :call <SID>RunCurrentLine(1)<CR>
vnoremap ~<Space> "0y:call <SID>RunVisualSelection(1)<CR>
vnoremap ~! y:let @z=trim(system(@"))<CR>gv"zp`[V`]
vnoremap <leader>Z <Esc>:set nofoldenable<CR>gvs<Esc>:let @z="# {{{\nstmv2 commit --until $(stm-select-chunk) <<'EOF' && stm-announce-announce \"$(stm-select-ticket)\"\n" . substitute(substitute(@", '^# {{{\n', '', ''), '\n# }}}\n', '\n', '') . "EOF\n# }}}\n"<CR>"zP:set foldenable<CR>zO`[v`]
nmap <leader>Z :let @z="\n"<cr>"zPkV<leader>Z<Esc>`]2ki
vnoremap <leader>z <Esc>:set nofoldenable<CR>gvs<Esc>:let @z="# {{{\nclaude --setting-sources \"\" --permission-mode default \"$(cat <<'EOF'\n" . substitute(substitute(@", '^\s*#\s*{{{\n\?', '', ''), '\n# }}}\n', '\n', '') . "EOF\n)\"\n# }}}\n"<CR>gv"zp:set foldenable<CR>zO`[V`]
nnoremap <leader>z :set nofoldenable<CR>:let @z="# {{{\nclaude --setting-sources \"\" --permission-mode default \"$(cat <<'EOF'\n\nEOF\n)\"\n# }}}"<cr>"zp:set foldenable<CR>zO2ji
nnoremap <leader>b :let @z="pad://" . trim(@") . " "<cr>[z0"zP
vnoremap <leader>B <Esc>:set nofoldenable<CR>gv!scaffold-scratchpad-agentic-workflow<CR>:set foldenable<CR>zO6ji
nnoremap <leader>B :set nofoldenable<CR>V!scaffold-scratchpad-agentic-workflow<CR>:set foldenable<CR>zO4ji
"nnoremap <leader><S-CR> [zV]z
nnoremap <leader>v :if getline('.') !~# '{{{' <bar> exe "silent! normal! [z" <bar> endif<CR>V]z

map <leader>` <cmd>silent! mkview <bar> edit .pad/index.zsh <bar> silent! loadview<cr>


function! s:GetClaudeCmd()
  let l:choice = inputlist([
    \ 'Select Claude mode:',
    \ '1. plan',
    \ '2. edit',
    \ '3. converse',
    \ '4. converse (user)',
    \ ])
  if l:choice < 1 || l:choice > 6
    return ''
  endif

  let l:uuid = tolower(substitute(system('uuidgen'), '\n', '', 'g'))
  let l:cmd = 'claude-session ' . l:uuid
  let l:setting_sources = ''
  let l:mode = ''
  let l:print = ''

  if l:choice == 1
    let l:mode = ' --permission-mode plan'
  elseif l:choice == 2
    let l:mode = ' --permission-mode acceptEdits'
  elseif l:choice == 3
    let l:mode = ' --setting-sources "" --settings ~/.claude/settings.notify.json'
  elseif l:choice == 4
    let l:mode = ' --setting-sources "user" --settings ~/.claude/settings.notify.json'
  endif

  return l:cmd . l:setting_sources . l:mode . l:print
endfunction

function! s:ClaudeVisual()
  let l:cmd = s:GetClaudeCmd()
  if l:cmd == '' | return | endif
  set nofoldenable
  " Delete the visual selection into the unnamed register
  silent! normal! gvd
  " Build the replacement text
  let l:content = substitute(substitute(@", '^# {{{\n', '', ''), '\n# }}}\n', '\n', '')
  let @z = "# {{{\n" . l:cmd . " -- \"$(cat <<'EOF'\n" . l:content . "EOF\n)\"\n# }}}\n\n"
  " Paste register z at current position
  silent! normal! "zP
  set foldenable
  silent! normal! zO
  call feedkeys("`[V`]", 'n')
endfunction

vnoremap <leader>z <Esc>:call <SID>ClaudeVisual()<CR>

function! s:NameFold() range
  let l:name = input('Buffer name: ')
  if l:name == ''
    normal! gv
    return
  endif
  let l:line = getline(a:firstline)
  call setline(a:firstline, 'pad://' . l:name . ' ' . l:line)
  execute 'normal! ' . a:firstline . 'GV' . a:lastline . 'G'
endfunction

vnoremap <leader>n :call <SID>NameFold()<CR>

function! FoldAround() range                                                              
    set nofoldenable                                                                      
    let [open, close] = split(&foldmarker, ',')                                           
    let cms = &commentstring
    let indent = matchstr(getline(a:firstline), '^\s*')                                   
    call append(a:lastline, indent . substitute(cms, '%s', close, ''))
    call append(a:firstline - 1, indent . substitute(cms, '%s', open, ''))
    set foldenable
    execute 'normal! ' . a:firstline . 'GzO'
    execute 'normal! ' . a:firstline . 'GV' . (a:lastline + 2) . 'G'
endfunction

vnoremap zf :call FoldAround()<CR>

" --- pad:// scratchpad scripts ---

function! s:ScratchpadScriptSync()
  if expand('%:p') !~# '\.pad/'
    return
  endif

  let l:lines = getline(1, '$')
  let l:total = len(l:lines)
  let l:i = 0

  while l:i < l:total
    let l:match = matchlist(l:lines[l:i], '^pad://\(\S\+\)')
    if !empty(l:match)
      let l:name = l:match[1]
      " Find matching # }}} tracking nested fold levels
      let l:depth = 1
      let l:j = l:i + 1
      while l:j < l:total && l:depth > 0
        if l:lines[l:j] =~# '{{{'
          let l:depth += 1
        endif
        if l:lines[l:j] =~# '}}}'
          let l:depth -= 1
        endif
        let l:j += 1
      endwhile
      " l:j is now one past the closing }}} line
      " Collect body lines between pad:// line and closing }}} (exclusive)
      let l:body = l:lines[l:i + 1 : l:j - 2]
      let l:header = [
      \ '#!/usr/bin/env zsh',
      \ 'set -euo pipefail',
      \ 'export CLAUDE_NVIM_SESSION_BUFFER_NAME=' . l:name,
      \ 'mybuf mybuf://' . l:name,
      \ ]
      let l:content = l:header + l:body

      let l:dir = '.pad/bin'
      call mkdir(l:dir, 'p')
      let l:path = l:dir . '/' . l:name
      call writefile(l:content, l:path)
      call system('chmod +x ' . shellescape(l:path))
    endif
    let l:i += 1
  endwhile
endfunction

augroup ScratchpadScripts
  autocmd!
  autocmd InsertLeave * call s:ScratchpadScriptSync()
  autocmd BufWritePost * call s:ScratchpadScriptSync()
augroup END

function! s:SwitchToExistingBuffer(name)
  for l:buf in getbufinfo({'buflisted': 1})
    if l:buf.name ==# a:name
      exe 'buffer ' . l:buf.bufnr
      return 1
    endif
  endfor
  return 0
endfunction

function! s:RunVisualSelection(background)
  let l:first_line = split(@0, '\n')[0]
  let l:match = matchlist(l:first_line, '^pad://\(\S\+\)')
  if !empty(l:match)
    let l:script_name = l:match[1]
    if !s:SwitchToExistingBuffer(l:script_name)
      call s:ScratchpadScriptSync()
      exe 'term zsh --login .pad/bin/' . l:script_name
    endif
  else
    let l:rand = system('head -c 7 /dev/urandom | base64 | tr -dc a-zA-Z | head -c 7')[:-2]
    let l:fname = '/tmp/vimcmd-' . l:rand
    call writefile(['set -euo pipefail', 'mybuf mybuf://vimcmd-' . l:rand] + split(@0, '\n'), l:fname, 'b')

    exe 'term zsh --login ' . l:fname
  endif
  if a:background
    buffer #
  else
    normal! i
  endif
endfunction

function! s:RunCurrentLine(background)
  if foldclosed('.') != -1
    let l:line = trim(getline(foldclosed('.')))
  else
    let l:line = trim(getline('.'))
  endif
  let l:match = matchlist(l:line, '^pad://\(\S\+\)')
  if !empty(l:match)
    let l:script_name = l:match[1]
    if !s:SwitchToExistingBuffer(l:script_name)
      call s:ScratchpadScriptSync()
      exe 'term zsh --login .pad/bin/' . l:script_name
    endif
  else
    exe 'term zsh --login -c ' . shellescape(l:line)
  endif
  if a:background
    buffer #
  else
    normal! i
  endif
endfunction
