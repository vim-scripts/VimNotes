" ------------------------------------------------------------------------------
" Filename:      ~/.vim/plugin/VimNotes.vim
" VimScript:
" Last Modified: 22 Nov 2003 06:06:54 PM by Dave Vehrs
" Maintainer:    Dave Vehrs (davev at ziplip.com)
" Description:   VimNotes helps organize a collection of notes.
" Copyright:     (C) 2003 Dave Vehrs
"                This script is free software; you can redistribute it and/or 
"                modify it under the terms of the GNU General Public License as 
"                published by the Free Software Foundation; either version 2 of 
"                the License, or (at your option) any later version.
" Install:       Save this file in your .vim/plugins/ directory or load it
"                manually with :source VimNotes.vim.
" ------------------------------------------------------------------------------
" Exit if already loaded.
if (exists("loaded_vimnotes") || &cp) | finish | endif
let g:loaded_vimnotes=1
" ------------------------------------------------------------------------------
" Configuration:                                                             {{{

" Default Notes Directory:
if (!exists("g:VN_DefaultDir"))
  let g:VN_DefaultDir = "~/Notes"
endif

" Folds Enabled:    ("0" to disable)
if (!exists("g:VN_FoldEnable"))
  let g:VN_FoldEnable = "1"
endif

" Note Header Configuration:
" The default ("d") header will include filename, created date and last
" modified date and by whom.  Or you can use a minimalist ("m") header.
if (!exists("g:VN_Header"))
  let g:VN_Header = "d"
endif

" Note Section Divider:
" Setting this to "1" will place a divider line of ---- between note sections.
" Setting it to "0", will disable a visible seperater but folding will still
" work on section breaks.
if (!exists("g:VN_SectionSep"))
  let g:VN_SectionSep = "1"
endif

" Default Web Browser:
if (!exists("g:VN_DefaultBrowser"))
  "let g:VN_DefaultBrowser = "konqueror"
  let g:VN_DefaultBrowser = "links -g"
  "let g:VN_DefaultBrowser = "konsole -e lynx"
  "let g:VN_DefaultBrowser = "xterm -e lynx"
  "let g:VN_DefaultBrowser = "mozilla"
endif


" Keymappings:
" If you would like to change any of the keymappings for this script,
" add the following lines:
"                map <-key-to-use> <PLUG><-function-to-map>
"                map! <-key-to-use> <PLUG><-function-to-map>
" Currently the following functions require keymappings:
" Default Config:
"                VN_Search               <F2>
"                VN_NewFile              <F3>
"                VN_NewSection           <F4>
"                VN_OpenHTTPLink         <F5>
" Example:
"                map  <F1> <Plug>VN_Search
"                map! <F1> <Plug>VN_Search

" Customizing Syntax Colors:
" You can link the group to an existing syntax group with this command:
"        highlight link <vimnotes-group>  <group>
" You can find the available group names in your current syntax file:
"        /usr/local/share/vim/vim62/colors/
" Default Config:
"                highlight link VN_Bullet          Comment
"                highlight link VN_Checkbox        Function
"                highlight link VN_CheckboxDone    Comment
"                highlight link VN_HyperTextJump   Function
"                highlight link VN_HyperTextEntry  Identifier
"                highlight link VN_Divider         Comment
"                highlight link VN_Header          Comment
"                highlight link VN_HeaderTopic     Function
"                highlight link VN_HTTP            String
"                highlight link VN_NumberedList    Comment
"                highlight link VN_Topic           Comment

"                                                                            }}}
" ------------------------------------------------------------------------------

" VN_AutoCommands:
augroup VN_AutoCommands
  autocmd!
  " Set filetype and options on load.
  autocmd BufRead,BufReadPost          *.txt     call <SID>VN_SetFT()
  " Update header before saving file.
  autocmd BufWritePre,FileWritePre     *.txt     kS|call <SID>VN_PreSave()
  autocmd FileAppendPre                *.txt     kS|call <SID>VN_PreSave()
  " Run helptags after the file is saved to keep the index (tags) up to date.
  autocmd BufWritePost,FileWritePost   *.txt     call <SID>VN_PostSave()|'S
  autocmd FileAppendPost               *.txt     call <SID>VN_PostSave()|'S
  " Set file options.
  autocmd FileType                     VimNote   call <SID>VN_Options()
  " Load menu in gvim.
  autocmd GUIEnter                     *         call <SID>VN_MenuGen()
  " Set color syntax for files
  autocmd Syntax                       VimNote   call <SID>VN_Syntax()
augroup end

" VN_Folds: Set folds for VimNote files
function! VN_Folds()
  let l:testline = getline(v:lnum)
  if (line(".") >= 1) | let l:preline = getline(v:lnum-1)
  else                | let l:preline = ""
  endif
  let l:postline = getline(v:lnum+1)
  let l:post2line = getline(v:lnum+2)
  let l:flvl = "0"
  " For VimNote Header  [[ Currently broken.  Works when the file is first
  "                        read but then breaks after the first write. ]]
  if ((line(".") <= 1   && l:testline =~ '^--*\sVimNote\s*$') &&
      \ l:postline !~ '^\S.*\*\S*\*\s*$')
    return "a1"
  elseif (l:postline =~ '^--*\s*$' && l:post2line =~ '^\S.*\*\S*\*\s*$')
    return "s1"
 " For the in-file index section
  elseif (l:testline =~ '^VNFile:.*'  || l:testline =~ '^Local:\s*$' )
    return "a1"
  elseif (l:postline =~ "^VNFile:.*" || (l:testline  =~ '\s*|\S*|\s*$' &&
         \ l:postline =~ '^\s*$'))
    return "s1"
  " For markers with Foldlevels
  elseif (l:testline =~ '{{{\d\+\s*$')
    let l:flvl = substitute(l:testline, '^.*{{{', '', 'g')
    return ">" . l:flvl
  elseif (l:testline =~ '}}}\d\+\s*$')
    let l:flvl = substitute(l:testline, '^.*}}}', '', 'g')
    return "<" . l:flvl
  " For markers without foldlevels
  elseif (l:testline =~ '{{{\s*$')
    return "a1"
  elseif (l:testline =~ '}}}\s*$')
    return "s1"
  " For note subsections
  elseif (l:testline =~  '^\S.*\*\S*\*\s*$' && (l:preline =~ '^--*--\s*$' ||
     \ l:preline =~ '\s*|\S*|\s*$' || l:preline =~ '^--*-- VimNote\s*$'))
    return "a1"
  elseif (l:testline =~ '\s*|\S*|\s*$')
    return "s1"
  else
    return "="
  endif
endfunction

" VN_FoldText: Custom text for folds
function! VN_FoldText()
  let l:return_line = ""
  let l:text_width = &textwidth - 16
  let l:linecount = v:foldend - v:foldstart + 1
  let l:line = getline(v:foldstart)
  " Trim leading spaces and keep count
  let l:line_indent = 0
  while  ( strpart(l:line,0,1) == " "  )
    let l:line = strpart(l:line,1)
    let l:line_indent = l:line_indent + 1
  endwhile
  " Cleanup line
  let l:line = substitute(l:line, '/\*\|\*/\|{{{\d\=', '', 'g')
  let l:line = substitute(l:line, '\s*\&\S*\*\s*$', '', 'g')
  let l:line = substitute(l:line, '\s*$', '', 'g')
  let l:line = substitute(l:line, '^-*\sVimNote\s*$', 'VimNote Header', 'g')
  " Trim line or pad to fit page width
  let l:text_width = l:text_width - l:line_indent
  if (strlen(l:line) > l:text_width)
    let l:line = strpart(l:line,0,l:text_width)."..."
  else
    while (strlen(l:line) <= l:text_width + 2)
      let l:line = l:line . " "
    endwhile
  endif
  " Put line indent back on
  while (strlen(l:return_line) < l:line_indent)
    let l:return_line = l:return_line . " "
  endwhile
  " Build line
  let l:return_line = l:return_line . "+ " . l:line . "[lines:"
  if (l:linecount <= 9)
    let l:return_line = l:return_line . "  " . l:linecount . "] "
  elseif (l:linecount <= 99)
    let l:return_line = l:return_line . " ". l:linecount . "] "
  else
    let l:return_line = l:return_line . l:linecount . "] "
  endif
  " Cover the rest of the screen width
  while (strlen(l:return_line) < winwidth(0))
    let l:return_line = l:return_line . " "
  endwhile
  return l:return_line
endfunction

" VN_HTTPLink: Open Link in default web browser
" Thanks to VimTip#306 by Kartik Agaram
function! <SID>VN_HTTPLink()
  let l:line = getline(".")
  let l:line = matchstr(l:line, '\(http:\|www\.\)[^,;\t]*')
  if ( l:line != "" )
    if (g:VN_DefaultBrowser == "mozilla")
      let l:tri = g:VN_DefaultBrowser . " -remote 'openurl("
        \ . l:line . ")' &"
      let l:call_running = system(l:tri)
      if ( l:call_running =~ '\(N\|n\)o running window found.')
        unlet l:tri
        let l:tri = g:VN_DefaultBrowser . " '" . l:line . "' &"
        let l:call_new = system(l:tri)
      endif
    else
      let l:tri =  g:VN_DefaultBrowser . " '" . l:line . "' &"
      let l:call_new = system(l:tri)
    endif
  endif
endfunction

" VN_Keys:  Load keymappings
function! s:VN_Keys()
  let l:alert = ""
  " Map create new note section
  if (!hasmapto('<PLUG>VN_NewSection') && (maparg('<F3>') == ''))
    map  <buffer> <F3> <Plug>VN_NewSection
    map! <buffer> <F3> <Plug>VN_NewSection
  elseif (!hasmapto('<PLUG>VN_NewSection'))
    let l:alert = s:VN_KeyAlert(l:alert,"New Section")
  endif
  " Map Open HTTP Link 
  if (!hasmapto('<PLUG>VN_OpenHTTPLink') && (maparg('<F5>') == ''))
    map  <buffer> <F5> <Plug>VN_OpenHTTPLink
    map! <buffer> <F5> <Plug>VN_OpenHTTPLink
  elseif (!hasmapto('<PLUG>VN_OpenHTTPLink'))
    let l:alert = s:VN_KeyAlert(l:alert,"New Section")
  endif
  " Map Search Query
  if (!hasmapto('<PLUG>VN_Search') && (maparg('<F4>') == ''))
    map  <buffer> <F4> <Plug>VN_Search
    map! <buffer> <F4> <Plug>VN_Search
  elseif (!hasmapto('<PLUG>VN_Search'))
    let l:alert = s:VN_KeyAlert(l:alert,"Search")
  endif
  " Alert of errors
  if (l:alert != "")
    if (!has("gui_running") || has("win32"))
       echo confirm ("VimNotes Error: No key mapping(s) assigned for the " .
       \             l:alert . " function(s)\n","&ok", 0, "Warning")
    endif
  endif
endfunction

" VN_KeysAlert: Process alert list
function! s:VN_KeyAlert(phrase,keyword)
  if (a:phrase == "") | return a:keyword
  else
    let l:local=substitute(a:phrase,',\sor\s',', ','g').", or ".a:keyword."."
    return l:local
  endif
endfunction

" VN_LastWindow: Close application if last window is a CWindow
" Thanks to Vimtip#536 by David Kalita
function! VN_LastWindow()
  if ( &buftype == "quickfix" )
    if winbufnr(2) == -1
      quit!
    endif
  endif
endfunction
 
" VN_MenuGen: Generate menu items for GVIM
function! <SID>VN_MenuGen()
  let l:menu_str = "menu <silent> 9009."
  execute l:menu_str . "100 VimNotes.Refresh   :call <SID>VN_MenuGen()<CR>"
  execute l:menu_str . "200 VimNotes.-sep-     :"
  if (&filetype == "VimNote") | let l:directory = expand("%:p:h")
  else        | let l:directory = expand(expand(g:VN_DefaultDir))
  endif
  call s:VN_ProcTFM(l:directory,l:menu_str,"300")
  execute l:menu_str . "9999 VimNotes.-sep-     :"
endfunction

" VN_NewNoteFile:  Create new note with header, etc.
function!  <SID>VN_NewNoteFile()
  let l:text_width = &textwidth
  if (&filetype == "VimNote") | let l:directory = expand("%:p:h")
  else        | let l:directory = expand(expand(g:VN_DefaultDir))
  endif
  call inputsave()
  let l:filename = input("New VimNote Filename (w/o .txt):")
  call inputrestore()
  execute "normal: new\<CR>"
  setfiletype VimNote
  " Create header top line as wide as configured textwidth
  let l:topline = "-"
  while (strlen(l:topline) < l:text_width - 8)
    let l:topline = l:topline . "-"
  endwhile
  let l:topline = l:topline . " VimNote"
  " Set date
  let l:today = strftime("%d %b %Y %X")
  " Set divider
  let l:divline = "-"
  while (strlen(l:divline) < l:text_width)
    let l:divline = l:divline . "-"
  endwhile
  " Set first index line
  let l:idxline = l:filename .": "
  while (strlen(l:idxline) < (l:text_width - (strlen(l:filename) + 2)))
    let l:idxline = l:idxline . " "
  endwhile
  let l:idxline = l:idxline . "*" . l:filename . "*"
  " Set first link line
  let l:linkline = " "
  while (strlen(l:linkline) < (l:text_width - (strlen(l:filename) + 2)))
    let l:linkline = l:linkline . " "
  endwhile
  let l:linkline = l:linkline . "|" . l:filename . "|"
  " Insert header (created from bottom to top)
  call append(0, l:divline)
  call append(0, l:linkline)
  let l:loop = 1
  while (l:loop < 10) | call append(0, "") | let l:loop = l:loop + 1 | endwhile
  if (g:VN_Header == "d")
    call append(0, l:idxline)
    call append(0, l:divline)
    call append(0, "Modified: " . l:today)
    call append(0, "Created: " . l:today)
    call append(0, "Filename: " . l:filename)
  else
    call append(0,l:idxline)
  endif
  call append(0, l:topline)
  execute "write ". g:VN_DefaultDir . "/" . l:filename . ".txt"
  setlocal nofoldenable
endfunction

" VN_NewNoteSection: Create new note section after current section
function! <SID>VN_NewNoteSection()
  let l:text_width = &textwidth
  " Set divider
  let l:divline = "-"
  while (strlen(l:divline) < l:text_width)
    let l:divline = l:divline . "-"
  endwhile
  " Set New Index line
  let l:newsect = "New Section: "
  while (strlen(l:newsect) < l:text_width - 12)
    let l:newsect = l:newsect . " "
  endwhile
  let l:newsect = l:newsect . "*NewSection*"
  let l:currline = line(".")
  let l:testline = getline(l:currline)
  let l:postline = getline(l:currline + 1)
  while (l:currline != line("$")   && (l:testline !~ '^\s\+|\S\+|\s*$' &&
      \ (l:postline !~ '^--\+\s*$' || l:postline !~ '^\S.*\s\+\*\S\+\*\s*$')))
    let l:currline = l:currline + 1
    let l:testline = getline(l:currline)
    let l:postline = getline(l:currline + 1)
  endwhile
  if (l:currline == line("$")) | return | endif
  if (g:VN_SectionSep == "0")
    call append(l:currline, l:newsect)
    call append(l:currline + 1, "")
    call append(l:currline + 2, l:testline)
  else
    call append(l:currline + 1, l:newsect)
    call append(l:currline + 2, "")
    call append(l:currline + 3, l:testline)
    call append(l:currline + 4, l:divline)
  endif
endfunction

" VN_OpenCWin: Determine the best window height for the new cwindow.
function! s:VN_OpenCWin()
  let l:mod_total = 0
  let l:win_count = 1
  " Determine correct window height
	windo let l:win_count =  l:win_count + 1
  if ( l:win_count <= 2 ) | let l:win_count = 4 | endif
  windo let l:mod_total = l:mod_total + winheight(0)/l:win_count |
  \ execute 'resize +'.l:mod_total
  " Open cwindow
  execute 'belowright copen '.l:mod_total
	let l:cwin_filelen = line("$")
  " Test for short output lists.
  if (l:cwin_filelen < winheight(0))
    cclose
    " And adjust cwindow height accordingly.
    execute 'belowright copen '.l:cwin_filelen
  endif
  " Set cwindow specific key mappings.
  nnoremap <buffer> <silent> c :cclose<CR>
  set nobuflisted
  return
endfunction

" VN_Options: set vim options for VimNote files
function! <SID>VN_Options()
  setlocal foldexpr=VN_Folds()
  setlocal foldmethod=expr
  setlocal foldtext=VN_FoldText()
  setlocal formatoptions=tcqn
  if (g:VN_FoldEnable == "0") | setlocal nofoldenable
  else                        | setlocal foldenable
  endif
  setlocal noswapfile
  setlocal shortmess=atTW
  setlocal tabstop=2
  setlocal textwidth=60
  if (has("GUI")) | execute <SID>VN_MenuGen() | endif
  " Load keymappings
  execute s:VN_Keys()   
endfunction

" VN_Plugs:  Load function plugs.
function! s:VN_Plugs()
  let l:alert = ""
  "------ Global keymapings available in all filetypes.  For VimNotes ONLY
  "       keymappings see the VN_Keys function.
  " Map create new note file
  if (!hasmapto('<PLUG>VN_NewFile') && (maparg('<F2>') == ''))
    map  <buffer> <F2> <Plug>VN_NewFile
    map! <buffer> <F2> <Plug>VN_NewFile
  elseif (!hasmapto('<PLUG>VN_NewFile'))
    let l:alert = s:VN_KeyAlert(l:alert,"New File")
  endif
  " Alert of errors
  if (l:alert != "")
    if (!has("gui_running") || has("win32"))
       echo confirm ("VimNotes Error: No key mapping(s) assigned for the " .
       \             l:alert . " function(s)\n","&ok", 0, "Warning")
    endif
  endif
  " Assign plugs
  noremap  <silent> <Plug>VN_NewFile    :call <SID>VN_NewNoteFile()<CR>
  noremap! <silent> <Plug>VN_NewFile    <ESC>:call <SID>VN_NewNoteFile()<CR>
  noremap  <silent> <Plug>VN_NewSection :call <SID>VN_NewNoteSection()<CR>
  noremap! <silent> <Plug>VN_NewSection <ESC>:call <SID>VN_HTTPLink()<CR>
  noremap  <silent> <Plug>VN_OpenHTTPLink :call <SID>VN_HTTPLink()<CR>
  noremap! <silent> <Plug>VN_OpenHTTPLink <ESC>:call <SID>VN_NewNoteSection()<CR>
  noremap  <silent> <Plug>VN_Search     :call <SID>VN_SearchP()<CR>
  noremap! <silent> <Plug>VN_Search     <ESC>:call <SID>VN_SearchP()<CR>
endfunction

" VN_PreSave: Update the header before saving
function! <SID>VN_PreSave()
  if (&filetype == "VimNote")
    if line("$") > 6 | let l:line_end = 6
    else              | let l:line_end = line("$")
    endif
    let l:today = strftime("%d %b %Y %X")
    let l:username = s:VN_User()
    if (l:username != "")
      execute ':1,' . l:line_end . 's/Modified: .*/Modified: ' . l:today .
            \ ' by ' . l:username . '/'
    else
      execute ':1,' . l:line_end . 's/Modified: .*/Modified: ' . l:today . '/'
    endif
    execute ':1,' . l:line_end . 's/Filename: .*/Filename: ' .
          \ expand("%:p:t") . '/'
  endif
endfunction

" VN_PostSave: Update the tags file every time a VimNote is saved
function! <SID>VN_PostSave()
  if (&filetype == "VimNote")
    execute "helptags ". expand("%:p:h")
    if (has("GUI")) | execute <SID>VN_MenuGen() | endif
  endif
endfunction

" VN_ProcTFM: Process Tag file for menu.
function! s:VN_ProcTFM(directory,menustr,menudepth)
  let l:filename = a:directory . "/tags"
  let l:menu_cmd = a:menustr
  if !filereadable(l:filename)
    execute "helptags ". a:directory
  endif
  " Need to replace this system call.
  let l:text = system("cat " . l:filename)
  if (l:text == '') | return | endif
  let l:counter = 0
  while (l:text != '')
    let l:line = strpart(l:text, 0, stridx(l:text, "\n"))
    let l:tag = substitute(l:line, '\s\S\+\s\S\+\s*$', '', 'g')
    let l:fname = substitute(l:line, '^\S\+\s\+', '', 'g')
    let l:fname = substitute(l:fname, '\s\+\S\+\s*$', '', 'g')
    let l:sfname = substitute(l:fname,'\.txt', '', 'g')
    execute l:menu_cmd . a:menudepth . " VimNotes." . l:sfname . "." . l:tag .
      \ " :edit " . a:directory . "/" . l:fname . " \\| tag " . l:tag .
      \ " \\| silent! foldopen<CR>"
    let l:text = strpart(l:text, stridx(l:text, "\n" ) + 1)
    let l:counter = l:counter + 1
  endwhile
  return
endfunction

" VN_SearchP: Prompts for search target and runs the search
" Note: Currently limited to 1 keyword per search
function! <SID>VN_SearchP()
	set lazyredraw
  cclose
  if (&filetype == "VimNote")    | let l:directory = expand("%:p:h") . "/*.txt"
  else           | let l:directory = expand(expand(g:VN_DefaultDir)) . "/*.txt"
  endif
  call inputsave()
  let l:keyword = input("Enter keyword to search for:")
  call inputrestore()
  silent! execute "grep! ". l:keyword . " " . l:directory
  if (&lines >= 8) | execute s:VN_OpenCWin()
  else | echo confirm("VimNotes Error: Window too small.\n", "&ok", 0, "Info")
  endif
	set nolazyredraw
	redraw!
endfunction

" VN_SetFT: Set the filetype on buffer load
function! <SID>VN_SetFT()
  if (did_filetype()) | return | endif
  if (getline(1) =~ '^--*-- VimNote\s*$') | setfiletype VimNote | endif
endfunction

" VN_Syntax: Syntax highlighting options (based on help.vim)
function! <SID>VN_Syntax()
  " For version 6.x: Quit when a syntax file was already loaded
  if exists("b:current_syntax") | finish | endif
  " Configure Links
  if (has("ebcdic"))
    syntax match VN_HyperTextJump	"\\\@<!|[^"*|]\+|"
    syntax match VN_HyperTextEntry	"\*[^"*|]\+\*\s"he=e-1
    syntax match VN_HyperTextEntry	"\*[^"*|]\+\*$"
  else
    syntax match VN_HyperTextJump	"\\\@<!|[#-)!+-~]\+|"
    syntax match VN_HyperTextEntry	"\*[#-)!+-~]\+\*\s"he=e-1
    syntax match VN_HyperTextEntry	"\*[#-)!+-~]\+\*$"
  endif
  " Configure special matches.
  syntax match VN_Bullet       '^\s*\-\s*'
  syntax match VN_Checkbox     '\[\s\]\s*$'
  syntax match VN_CheckboxDone '\[X\]\s*$'
  syntax match VN_Divider      '^--*--\s*$'
  syntax match VN_HeaderTopic  '^\s*\S*:\{1}'
  syntax match VN_HTTP         'http:\/\/\S*\s*'
  syntax match VN_NumberedList '^\s*\d\.\s'
  syntax match VN_Topic        '^\s*\S.*:\{1}\s*'
  " Configure special regions.
  syntax region VN_Header start='\%^--\+\sVimNote\s*$' end='^--\+\s*$'
    \ contains=VN_HTopic
  " Link to existing syntax items.
  highlight link VN_Bullet          Comment
  highlight link VN_Checkbox        Function
  highlight link VN_CheckboxDone    Comment
  highlight link VN_HyperTextJump   Function
  highlight link VN_HyperTextEntry  Identifier
  highlight link VN_Divider         Comment
  highlight link VN_Header          Comment
  highlight link VN_HeaderTopic     String
  highlight link VN_HTTP            Function
  highlight link VN_NumberedList    Comment
  highlight link VN_Topic           Comment
endfunction

" VN_User: Determine user name for VN_UpdateTS
function! s:VN_User()
  let l:user = ""
  if (has("unix"))
    let l:user = $USER
    if (filereadable("/etc/passwd"))
      let l:temp = strtrans(system("grep ".l:user." /etc/passwd | ".
        \ "cut -d : -f 5"))
      let l:temp = strpart(l:temp,0,stridx(l:temp,"^@"))
      if (l:temp != "" || l:temp != "^@") | let l:user = l:temp | endif
    endif
  endif
 	return l:user
endfunction

" ------------------------------------------------------------------------------
" Misc.                                                                      {{{

" Enable filetype detection
filetype on

" Load function plugs
execute s:VN_Plugs()
   
"                                                                            }}}
" ------------------------------------------------------------------------------
" vim:tw=80:ts=2:ft=vim:norl:
