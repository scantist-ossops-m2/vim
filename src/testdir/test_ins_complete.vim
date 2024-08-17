" Test for insert completion

source screendump.vim
source check.vim
source vim9.vim

" Test for insert expansion
func Test_ins_complete()
  edit test_ins_complete.vim
  " The files in the current directory interferes with the files
  " used by this test. So use a separate directory for the test.
  call mkdir('Xdir')
  cd Xdir

  set ff=unix
  call writefile(["test11\t36Gepeto\t/Tag/",
	      \ "asd\ttest11file\t36G",
	      \ "Makefile\tto\trun"], 'Xtestfile')
  call writefile(['', 'start of testfile',
	      \ 'ru',
	      \ 'run1',
	      \ 'run2',
	      \ 'STARTTEST',
	      \ 'ENDTEST',
	      \ 'end of testfile'], 'Xtestdata')
  set ff&

  enew!
  edit Xtestdata
  new
  call append(0, ['#include "Xtestfile"', ''])
  call cursor(2, 1)

  set cot=
  set cpt=.,w
  " add-expands (word from next line) from other window
  exe "normal iru\<C-N>\<C-N>\<C-X>\<C-N>\<Esc>\<C-A>"
  call assert_equal('run1 run3', getline('.'))
  " add-expands (current buffer first)
  exe "normal o\<C-P>\<C-X>\<C-N>"
  call assert_equal('run3 run3', getline('.'))
  " Local expansion, ends in an empty line (unless it becomes a global
  " expansion)
  exe "normal o\<C-X>\<C-P>\<C-P>\<C-P>\<C-P>\<C-P>"
  call assert_equal('', getline('.'))
  " starts Local and switches to global add-expansion
  exe "normal o\<C-X>\<C-P>\<C-P>\<C-X>\<C-X>\<C-N>\<C-X>\<C-N>\<C-N>"
  call assert_equal('run1 run2', getline('.'))

  set cpt=.,w,i
  " i-add-expands and switches to local
  exe "normal OM\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>\<C-X>\<C-X>\<C-X>\<C-P>"
  call assert_equal("Makefile\tto\trun3", getline('.'))
  " add-expands lines (it would end in an empty line if it didn't ignore
  " itself)
  exe "normal o\<C-X>\<C-L>\<C-X>\<C-L>\<C-P>\<C-P>"
  call assert_equal("Makefile\tto\trun3", getline('.'))
  call assert_equal("Makefile\tto\trun3", getline(line('.') - 1))

  set cpt=kXtestfile
  " checks k-expansion, and file expansion (use Xtest11 instead of test11,
  " because TEST11.OUT may match first on DOS)
  write Xtest11.one
  write Xtest11.two
  exe "normal o\<C-N>\<Esc>IX\<Esc>A\<C-X>\<C-F>\<C-N>"
  call assert_equal('Xtest11.two', getline('.'))

  " use CTRL-X CTRL-F to complete Xtest11.one, remove it and then use CTRL-X
  " CTRL-F again to verify this doesn't cause trouble.
  exe "normal oXt\<C-X>\<C-F>\<BS>\<BS>\<BS>\<BS>\<BS>\<BS>\<BS>\<BS>\<C-X>\<C-F>"
  call assert_equal('Xtest11.one', getline('.'))
  normal ddk

  set cpt=w
  " checks make_cyclic in other window
  exe "normal oST\<C-N>\<C-P>\<C-P>\<C-P>\<C-P>"
  call assert_equal('STARTTEST', getline('.'))

  set cpt=u nohid
  " checks unloaded buffer expansion
  only
  exe "normal oEN\<C-N>"
  call assert_equal('ENDTEST', getline('.'))
  " checks adding mode abortion
  exe "normal ounl\<C-N>\<C-X>\<C-X>\<C-P>"
  call assert_equal('unless', getline('.'))

  set cpt=t,d def=^\\k* tags=Xtestfile notagbsearch
  " tag expansion, define add-expansion interrupted
  exe "normal o\<C-X>\<C-]>\<C-X>\<C-D>\<C-X>\<C-D>\<C-X>\<C-X>\<C-D>\<C-X>\<C-D>\<C-X>\<C-D>\<C-X>\<C-D>"
  call assert_equal('test11file	36Gepeto	/Tag/ asd', getline('.'))
  " t-expansion
  exe "normal oa\<C-N>\<Esc>"
  call assert_equal('asd', getline('.'))

  %bw!
  call delete('Xtestfile')
  call delete('Xtest11.one')
  call delete('Xtest11.two')
  call delete('Xtestdata')
  set cpt& cot& def& tags& tagbsearch& hidden&
  cd ..
  call delete('Xdir', 'rf')
endfunc

func Test_omni_dash()
  func Omni(findstart, base)
    if a:findstart
        return 5
    else
        echom a:base
	return ['-help', '-v']
    endif
  endfunc
  set omnifunc=Omni
  new
  exe "normal Gofind -\<C-x>\<C-o>"
  call assert_equal("find -help", getline('$'))

  bwipe!
  delfunc Omni
  set omnifunc=
endfunc

func Test_omni_autoload()
  let save_rtp = &rtp
  set rtp=Xruntime/some
  let dir = 'Xruntime/some/autoload'
  call mkdir(dir, 'p')

  let lines =<< trim END
      vim9script
      def omni#func(findstart: bool, base: string): any
          if findstart
              return 1
          else
              return ['match']
          endif
      enddef
      {
          eval 1 + 2
      }
  END
  call writefile(lines, dir .. '/omni.vim')

  new
  setlocal omnifunc=omni#func
  call feedkeys("i\<C-X>\<C-O>\<Esc>", 'xt')

  bwipe!
  call delete('Xruntime', 'rf')
  set omnifunc=
  let &rtp = save_rtp
endfunc

func Test_completefunc_args()
  let s:args = []
  func! CompleteFunc(findstart, base)
    let s:args += [[a:findstart, empty(a:base)]]
  endfunc
  new

  set completefunc=CompleteFunc
  call feedkeys("i\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([1, 1], s:args[0])
  call assert_equal(0, s:args[1][0])
  set completefunc=

  let s:args = []
  set omnifunc=CompleteFunc
  call feedkeys("i\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([1, 1], s:args[0])
  call assert_equal(0, s:args[1][0])
  set omnifunc=

  bwipe!
  unlet s:args
  delfunc CompleteFunc
endfunc

func s:CompleteDone_CompleteFuncNone( findstart, base )
  if a:findstart
    return 0
  endif

  return v:none
endfunc

func s:CompleteDone_CompleteFuncDict( findstart, base )
  if a:findstart
    return 0
  endif

  return {
	  \ 'words': [
	    \ {
	      \ 'word': 'aword',
	      \ 'abbr': 'wrd',
	      \ 'menu': 'extra text',
	      \ 'info': 'words are cool',
	      \ 'kind': 'W',
	      \ 'user_data': 'test'
	    \ }
	  \ ]
	\ }
endfunc

func s:CompleteDone_CheckCompletedItemNone()
  let s:called_completedone = 1
endfunc

func s:CompleteDone_CheckCompletedItemDict(pre)
  call assert_equal( 'aword',          v:completed_item[ 'word' ] )
  call assert_equal( 'wrd',            v:completed_item[ 'abbr' ] )
  call assert_equal( 'extra text',     v:completed_item[ 'menu' ] )
  call assert_equal( 'words are cool', v:completed_item[ 'info' ] )
  call assert_equal( 'W',              v:completed_item[ 'kind' ] )
  call assert_equal( 'test',           v:completed_item[ 'user_data' ] )

  if a:pre
    call assert_equal('function', complete_info().mode)
  endif

  let s:called_completedone = 1
endfunc

func Test_CompleteDoneNone()
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemNone()
  let oldline = join(map(range(&columns), 'nr2char(screenchar(&lines-1, v:val+1))'), '')

  set completefunc=<SID>CompleteDone_CompleteFuncNone
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&
  let newline = join(map(range(&columns), 'nr2char(screenchar(&lines-1, v:val+1))'), '')

  call assert_true(s:called_completedone)
  call assert_equal(oldline, newline)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func Test_CompleteDoneDict()
  au CompleteDonePre * :call <SID>CompleteDone_CheckCompletedItemDict(1)
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemDict(0)

  set completefunc=<SID>CompleteDone_CompleteFuncDict
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&

  call assert_equal('test', v:completed_item[ 'user_data' ])
  call assert_true(s:called_completedone)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func s:CompleteDone_CompleteFuncDictNoUserData(findstart, base)
  if a:findstart
    return 0
  endif

  return {
	  \ 'words': [
	    \ {
	      \ 'word': 'aword',
	      \ 'abbr': 'wrd',
	      \ 'menu': 'extra text',
	      \ 'info': 'words are cool',
	      \ 'kind': 'W',
	      \ 'user_data': ['one', 'two'],
	    \ }
	  \ ]
	\ }
endfunc

func s:CompleteDone_CheckCompletedItemDictNoUserData()
  call assert_equal( 'aword',          v:completed_item[ 'word' ] )
  call assert_equal( 'wrd',            v:completed_item[ 'abbr' ] )
  call assert_equal( 'extra text',     v:completed_item[ 'menu' ] )
  call assert_equal( 'words are cool', v:completed_item[ 'info' ] )
  call assert_equal( 'W',              v:completed_item[ 'kind' ] )
  call assert_equal( ['one', 'two'],   v:completed_item[ 'user_data' ] )

  let s:called_completedone = 1
endfunc

func Test_CompleteDoneDictNoUserData()
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemDictNoUserData()

  set completefunc=<SID>CompleteDone_CompleteFuncDictNoUserData
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&

  call assert_equal(['one', 'two'], v:completed_item[ 'user_data' ])
  call assert_true(s:called_completedone)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func s:CompleteDone_CompleteFuncList(findstart, base)
  if a:findstart
    return 0
  endif

  return [ 'aword' ]
endfunc

func s:CompleteDone_CheckCompletedItemList()
  call assert_equal( 'aword', v:completed_item[ 'word' ] )
  call assert_equal( '',      v:completed_item[ 'abbr' ] )
  call assert_equal( '',      v:completed_item[ 'menu' ] )
  call assert_equal( '',      v:completed_item[ 'info' ] )
  call assert_equal( '',      v:completed_item[ 'kind' ] )
  call assert_equal( '',      v:completed_item[ 'user_data' ] )

  let s:called_completedone = 1
endfunc

func Test_CompleteDoneList()
  au CompleteDone * :call <SID>CompleteDone_CheckCompletedItemList()

  set completefunc=<SID>CompleteDone_CompleteFuncList
  execute "normal a\<C-X>\<C-U>\<C-Y>"
  set completefunc&

  call assert_equal('', v:completed_item[ 'user_data' ])
  call assert_true(s:called_completedone)

  let s:called_completedone = 0
  au! CompleteDone
endfunc

func Test_CompleteDone_undo()
  au CompleteDone * call append(0, "prepend1")
  new
  call setline(1, ["line1", "line2"])
  call feedkeys("Go\<C-X>\<C-N>\<CR>\<ESC>", "tx")
  call assert_equal(["prepend1", "line1", "line2", "line1", ""],
              \     getline(1, '$'))
  undo
  call assert_equal(["line1", "line2"], getline(1, '$'))
  bwipe!
  au! CompleteDone
endfunc

func CompleteTest(findstart, query)
  if a:findstart
    return col('.')
  endif
  return ['matched']
endfunc

func Test_completefunc_info()
  new
  set completeopt=menuone
  set completefunc=CompleteTest
  call feedkeys("i\<C-X>\<C-U>\<C-R>\<C-R>=string(complete_info())\<CR>\<ESC>", "tx")
  call assert_equal("matched{'pum_visible': 1, 'mode': 'function', 'selected': 0, 'items': [{'word': 'matched', 'menu': '', 'user_data': '', 'info': '', 'kind': '', 'abbr': ''}]}", getline(1))
  bwipe!
  set completeopt&
  set completefunc&
endfunc

" Check that when using feedkeys() typeahead does not interrupt searching for
" completions.
func Test_compl_feedkeys()
  new
  set completeopt=menuone,noselect
  call feedkeys("ajump ju\<C-X>\<C-N>\<C-P>\<ESC>", "tx")
  call assert_equal("jump jump", getline(1))
  bwipe!
  set completeopt&
endfunc

func s:ComplInCmdwin_GlobalCompletion(a, l, p)
  return 'global'
endfunc

func s:ComplInCmdwin_LocalCompletion(a, l, p)
  return 'local'
endfunc

func Test_compl_in_cmdwin()
  CheckFeature cmdwin

  set wildmenu wildchar=<Tab>
  com! -nargs=1 -complete=command GetInput let input = <q-args>
  com! -buffer TestCommand echo 'TestCommand'
  let w:test_winvar = 'winvar'
  let b:test_bufvar = 'bufvar'

  " User-defined commands
  let input = ''
  call feedkeys("q:iGetInput T\<C-x>\<C-v>\<CR>", 'tx!')
  call assert_equal('TestCommand', input)

  let input = ''
  call feedkeys("q::GetInput T\<Tab>\<CR>:q\<CR>", 'tx!')
  call assert_equal('T', input)


  com! -nargs=1 -complete=var GetInput let input = <q-args>
  " Window-local variables
  let input = ''
  call feedkeys("q:iGetInput w:test_\<C-x>\<C-v>\<CR>", 'tx!')
  call assert_equal('w:test_winvar', input)

  let input = ''
  call feedkeys("q::GetInput w:test_\<Tab>\<CR>:q\<CR>", 'tx!')
  call assert_equal('w:test_', input)

  " Buffer-local variables
  let input = ''
  call feedkeys("q:iGetInput b:test_\<C-x>\<C-v>\<CR>", 'tx!')
  call assert_equal('b:test_bufvar', input)

  let input = ''
  call feedkeys("q::GetInput b:test_\<Tab>\<CR>:q\<CR>", 'tx!')
  call assert_equal('b:test_', input)

func Test_ins_complete_add()
  " this was reading past the end of allocated memory
  new
  norm o
  norm 7o
  sil! norm o

  bwipe!
endfunc


  " Argument completion of buffer-local command
  func s:ComplInCmdwin_GlobalCompletionList(a, l, p)
    return ['global']
  endfunc

  func s:ComplInCmdwin_LocalCompletionList(a, l, p)
    return ['local']
  endfunc

  func s:ComplInCmdwin_CheckCompletion(arg)
    call assert_equal('local', a:arg)
  endfunc

  com! -nargs=1 -complete=custom,<SID>ComplInCmdwin_GlobalCompletion
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)
  com! -buffer -nargs=1 -complete=custom,<SID>ComplInCmdwin_LocalCompletion
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)
  call feedkeys("q:iTestCommand \<Tab>\<CR>", 'tx!')

  com! -nargs=1 -complete=customlist,<SID>ComplInCmdwin_GlobalCompletionList
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)
  com! -buffer -nargs=1 -complete=customlist,<SID>ComplInCmdwin_LocalCompletionList
       \ TestCommand call s:ComplInCmdwin_CheckCompletion(<q-args>)

  call feedkeys("q:iTestCommand \<Tab>\<CR>", 'tx!')

  func! s:ComplInCmdwin_CheckCompletion(arg)
    call assert_equal('global', a:arg)
  endfunc
  new
  call feedkeys("q:iTestCommand \<Tab>\<CR>", 'tx!')
  quit

  delfunc s:ComplInCmdwin_GlobalCompletion
  delfunc s:ComplInCmdwin_LocalCompletion
  delfunc s:ComplInCmdwin_GlobalCompletionList
  delfunc s:ComplInCmdwin_LocalCompletionList
  delfunc s:ComplInCmdwin_CheckCompletion

  delcom -buffer TestCommand
  delcom TestCommand
  delcom GetInput
  unlet w:test_winvar
  unlet b:test_bufvar
  set wildmenu& wildchar&
endfunc

" Test for insert path completion with completeslash option
func Test_ins_completeslash()
  CheckMSWindows

  call mkdir('Xdir')
  let orig_shellslash = &shellslash
  set cpt&
  new

  set noshellslash

  set completeslash=
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir\', getline('.'))

  set completeslash=backslash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir\', getline('.'))

  set completeslash=slash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir/', getline('.'))

  set shellslash

  set completeslash=
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir/', getline('.'))

  set completeslash=backslash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir\', getline('.'))

  set completeslash=slash
  exe "normal oXd\<C-X>\<C-F>"
  call assert_equal('Xdir/', getline('.'))
  %bw!
  call delete('Xdir', 'rf')

  set noshellslash
  set completeslash=slash
  call assert_true(stridx(globpath(&rtp, 'syntax/*.vim', 1, 1)[0], '\') != -1)

  let &shellslash = orig_shellslash
  set completeslash=
endfunc

func Test_pum_stopped_by_timer()
  CheckScreendump

  let lines =<< trim END
    call setline(1, ['hello', 'hullo', 'heeee', ''])
    func StartCompl()
      call timer_start(100, { -> execute('stopinsert') })
      call feedkeys("Gah\<C-N>")
    endfunc
  END

  call writefile(lines, 'Xpumscript')
  let buf = RunVimInTerminal('-S Xpumscript', #{rows: 12})
  call term_sendkeys(buf, ":call StartCompl()\<CR>")
  call TermWait(buf, 200)
  call term_sendkeys(buf, "k")
  call VerifyScreenDump(buf, 'Test_pum_stopped_by_timer', {})

  call StopVimInTerminal(buf)
  call delete('Xpumscript')
endfunc

func Test_pum_with_folds_two_tabs()
  CheckScreendump

  let lines =<< trim END
    set fdm=marker
    call setline(1, ['" x {{{1', '" a some text'])
    call setline(3, range(&lines)->map({_, val -> '" a' .. val}))
    norm! zm
    tab sp
    call feedkeys('2Gzv', 'xt')
    call feedkeys("0fa", 'xt')
  END

  call writefile(lines, 'Xpumscript')
  let buf = RunVimInTerminal('-S Xpumscript', #{rows: 10})
  call TermWait(buf, 50)
  call term_sendkeys(buf, "a\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_with_folds_two_tabs', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('Xpumscript')
endfunc

func Test_pum_with_preview_win()
  CheckScreendump

  let lines =<< trim END
      funct Omni_test(findstart, base)
	if a:findstart
	  return col(".") - 1
	endif
	return [#{word: "one", info: "1info"}, #{word: "two", info: "2info"}, #{word: "three", info: "3info"}]
      endfunc
      set omnifunc=Omni_test
      set completeopt+=longest
  END

  call writefile(lines, 'Xpreviewscript')
  let buf = RunVimInTerminal('-S Xpreviewscript', #{rows: 12})
  call TermWait(buf, 50)
  call term_sendkeys(buf, "Gi\<C-X>\<C-O>")
  call TermWait(buf, 100)
  call term_sendkeys(buf, "\<C-N>")
  call VerifyScreenDump(buf, 'Test_pum_with_preview_win', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
  call delete('Xpreviewscript')
endfunc

" Test for inserting the tag search pattern in insert mode
func Test_ins_compl_tag_sft()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t/^int first() {}$/",
        \ "second\tXfoo\t/^int second() {}$/",
        \ "third\tXfoo\t/^int third() {}$/"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew
  set showfulltag
  exe "normal isec\<C-X>\<C-]>\<C-N>\<CR>"
  call assert_equal('int second() {}', getline(1))
  set noshowfulltag

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe!
endfunc

" Test for 'completefunc' deleting text
func Test_completefunc_error()
  new
  " delete text when called for the first time
  func CompleteFunc(findstart, base)
    if a:findstart == 1
      normal dd
      return col('.') - 1
    endif
    return ['a', 'b']
  endfunc
  set completefunc=CompleteFunc
  call setline(1, ['', 'abcd', ''])
  call assert_fails('exe "normal 2G$a\<C-X>\<C-U>"', 'E578:')

  " delete text when called for the second time
  func CompleteFunc2(findstart, base)
    if a:findstart == 1
      return col('.') - 1
    endif
    normal dd
    return ['a', 'b']
  endfunc
  set completefunc=CompleteFunc2
  call setline(1, ['', 'abcd', ''])
  call assert_fails('exe "normal 2G$a\<C-X>\<C-U>"', 'E578:')

  " Jump to a different window from the complete function
  func CompleteFunc3(findstart, base)
    if a:findstart == 1
      return col('.') - 1
    endif
    wincmd p
    return ['a', 'b']
  endfunc
  set completefunc=CompleteFunc3
  new
  call assert_fails('exe "normal a\<C-X>\<C-U>"', 'E565:')
  close!

  set completefunc&
  delfunc CompleteFunc
  delfunc CompleteFunc2
  delfunc CompleteFunc3
  close!
endfunc

" Test for returning non-string values from 'completefunc'
func Test_completefunc_invalid_data()
  new
  func! CompleteFunc(findstart, base)
    if a:findstart == 1
      return col('.') - 1
    endif
    return [{}, '', 'moon']
  endfunc
  set completefunc=CompleteFunc
  exe "normal i\<C-X>\<C-U>"
  call assert_equal('moon', getline(1))
  set completefunc&
  close!
endfunc

" Test for errors in using complete() function
func Test_complete_func_error()
  call assert_fails('call complete(1, ["a"])', 'E785:')
  func ListColors()
    call complete(col('.'), "blue")
  endfunc
  call assert_fails('exe "normal i\<C-R>=ListColors()\<CR>"', 'E474:')
  func ListMonths()
    call complete(col('.'), test_null_list())
  endfunc
  call assert_fails('exe "normal i\<C-R>=ListMonths()\<CR>"', 'E474:')
  delfunc ListColors
  delfunc ListMonths
  call assert_fails('call complete_info({})', 'E714:')
  call assert_equal([], complete_info(['items']).items)
endfunc

" Test for completing words following a completed word in a line
func Test_complete_wrapscan()
  " complete words from another buffer
  new
  call setline(1, ['one two', 'three four'])
  new
  setlocal complete=w
  call feedkeys("itw\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>", 'xt')
  call assert_equal('two three four', getline(1))
  close!
  " complete words from the current buffer
  setlocal complete=.
  %d
  call setline(1, ['one two', ''])
  call cursor(2, 1)
  call feedkeys("ion\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>\<C-X>\<C-N>", 'xt')
  call assert_equal('one two one two', getline(2))
  close!
endfunc

" Test for completing special characters
func Test_complete_special_chars()
  new
  call setline(1, 'int .*[-\^$ func float')
  call feedkeys("oin\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>", 'xt')
  call assert_equal('int .*[-\^$ func float', getline(2))
  close!
endfunc

" Test for completion when text is wrapped across lines.
func Test_complete_across_line()
  new
  call setline(1, ['red green blue', 'one two three'])
  setlocal textwidth=20
  exe "normal 2G$a re\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>\<C-X>\<C-P>"
  call assert_equal(['one two three red', 'green blue one'], getline(2, '$'))
  close!
endfunc

" Test for using CTRL-L to add one character when completing matching
func Test_complete_add_onechar()
  new
  call setline(1, ['wool', 'woodwork'])
  call feedkeys("Gowoo\<C-P>\<C-P>\<C-P>\<C-L>f", 'xt')
  call assert_equal('woof', getline(3))

  " use 'ignorecase' and backspace to erase characters from the prefix string
  " and then add letters using CTRL-L
  %d
  set ignorecase backspace=2
  setlocal complete=.
  call setline(1, ['workhorse', 'workload'])
  normal Go
  exe "normal aWOR\<C-P>\<bs>\<bs>\<bs>\<bs>\<bs>\<bs>\<C-L>r\<C-L>\<C-L>"
  call assert_equal('workh', getline(3))
  set ignorecase& backspace&
  close!
endfunc

" Test insert completion with 'cindent' (adjust the indent)
func Test_complete_with_cindent()
  new
  setlocal cindent
  call setline(1, ['if (i == 1)', "    j = 2;"])
  exe "normal Go{\<CR>i\<C-X>\<C-L>\<C-X>\<C-L>\<CR>}"
  call assert_equal(['{', "\tif (i == 1)", "\t\tj = 2;", '}'], getline(3, '$'))

  %d
  call setline(1, ['when while', '{', ''])
  setlocal cinkeys+==while
  exe "normal Giwh\<C-P> "
  call assert_equal("\twhile ", getline('$'))
  close!
endfunc

" Test for <CTRL-X> <CTRL-V> completion. Complete commands and functions
func Test_complete_cmdline()
  new
  exe "normal icaddb\<C-X>\<C-V>"
  call assert_equal('caddbuffer', getline(1))
  exe "normal ocall getqf\<C-X>\<C-V>"
  call assert_equal('call getqflist(', getline(2))
  exe "normal oabcxyz(\<C-X>\<C-V>"
  call assert_equal('abcxyz(', getline(3))
  com! -buffer TestCommand1 echo 'TestCommand1'
  com! -buffer TestCommand2 echo 'TestCommand2'
  write TestCommand1Test
  write TestCommand2Test
  " Test repeating <CTRL-X> <CTRL-V> and switching to another CTRL-X mode
  exe "normal oT\<C-X>\<C-V>\<C-X>\<C-V>\<C-X>\<C-F>\<Esc>"
  call assert_equal('TestCommand2Test', getline(4))
  call delete('TestCommand1Test')
  call delete('TestCommand2Test')
  delcom TestCommand1
  delcom TestCommand2
  close!
endfunc

" Test for <CTRL-X> <CTRL-Z> stopping completion without changing the match
func Test_complete_stop()
  new
  func Save_mode1()
    let g:mode1 = mode(1)
    return ''
  endfunc
  func Save_mode2()
    let g:mode2 = mode(1)
    return ''
  endfunc
  inoremap <F1> <C-R>=Save_mode1()<CR>
  inoremap <F2> <C-R>=Save_mode2()<CR>
  call setline(1, ['aaa bbb ccc '])
  exe "normal A\<C-N>\<C-P>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc ', getline(1))
  exe "normal A\<C-N>\<Down>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc aaa', getline(1))
  set completeopt+=noselect
  exe "normal A \<C-N>\<Down>\<Down>\<C-L>\<C-L>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc aaa bb', getline(1))
  set completeopt&
  exe "normal A d\<C-N>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('aaa bbb ccc aaa bb d', getline(1))
  com! -buffer TestCommand1 echo 'TestCommand1'
  com! -buffer TestCommand2 echo 'TestCommand2'
  exe "normal oT\<C-X>\<C-V>\<C-X>\<C-V>\<F1>\<C-X>\<C-Z>\<F2>\<Esc>"
  call assert_equal('ic', g:mode1)
  call assert_equal('i', g:mode2)
  call assert_equal('TestCommand2', getline(2))
  delcom TestCommand1
  delcom TestCommand2
  unlet g:mode1
  unlet g:mode2
  iunmap <F1>
  iunmap <F2>
  delfunc Save_mode1
  delfunc Save_mode2
  close!
endfunc

func Test_issue_7021()
  CheckMSWindows

  let orig_shellslash = &shellslash
  set noshellslash

  set completeslash=slash
  call assert_false(expand('~') =~ '/')

  let &shellslash = orig_shellslash
  set completeslash=
endfunc

" Test to ensure 'Scanning...' messages are not recorded in messages history
func Test_z1_complete_no_history()
  new
  messages clear
  let currmess = execute('messages')
  setlocal dictionary=README.txt
  exe "normal owh\<C-X>\<C-K>"
  exe "normal owh\<C-N>"
  call assert_equal(currmess, execute('messages'))
  close!
endfunc

" Test for different ways of setting the 'completefunc' option
func Test_completefunc_callback()
  " Test for using a function()
  func MycompleteFunc1(findstart, base)
    call add(g:MycompleteFunc1_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set completefunc=function('MycompleteFunc1')
  new | only
  call setline(1, 'one')
  let g:MycompleteFunc1_args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'one']], g:MycompleteFunc1_args)
  bw!

  " Using a funcref variable to set 'completefunc'
  let Fn = function('MycompleteFunc1')
  let &completefunc = string(Fn)
  new | only
  call setline(1, 'two')
  let g:MycompleteFunc1_args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'two']], g:MycompleteFunc1_args)
  call assert_fails('let &completefunc = Fn', 'E729:')
  bw!

  " Test for using a funcref()
  func MycompleteFunc2(findstart, base)
    call add(g:MycompleteFunc2_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set completefunc=funcref('MycompleteFunc2')
  new | only
  call setline(1, 'three')
  let g:MycompleteFunc2_args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'three']], g:MycompleteFunc2_args)
  bw!

  " Using a funcref variable to set 'completefunc'
  let Fn = funcref('MycompleteFunc2')
  let &completefunc = string(Fn)
  new | only
  call setline(1, 'four')
  let g:MycompleteFunc2_args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'four']], g:MycompleteFunc2_args)
  call assert_fails('let &completefunc = Fn', 'E729:')
  bw!

  " Test for using a lambda function
  func MycompleteFunc3(findstart, base)
    call add(g:MycompleteFunc3_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set completefunc={a,\ b\ ->\ MycompleteFunc3(a,\ b)}
  new | only
  call setline(1, 'five')
  let g:MycompleteFunc3_args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'five']], g:MycompleteFunc3_args)
  bw!

  " Set 'completefunc' to a lambda expression
  let &completefunc = '{a, b -> MycompleteFunc3(a, b)}'
  new | only
  call setline(1, 'six')
  let g:MycompleteFunc3_args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'six']], g:MycompleteFunc3_args)
  bw!

  " Set 'completefunc' to a variable with a lambda expression
  let Lambda = {a, b -> MycompleteFunc3(a, b)}
  let &completefunc = string(Lambda)
  new | only
  call setline(1, 'seven')
  let g:MycompleteFunc3_args = []
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'seven']], g:MycompleteFunc3_args)
  call assert_fails('let &completefunc = Lambda', 'E729:')
  bw!

  " Test for using a lambda function with incorrect return value
  let Lambda = {s -> strlen(s)}
  let &completefunc = string(Lambda)
  new | only
  call setline(1, 'eight')
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
  bw!

  " Test for clearing the 'completefunc' option
  set completefunc=''
  set completefunc&

  call assert_fails("set completefunc=function('abc')", "E700:")
  call assert_fails("set completefunc=funcref('abc')", "E700:")
  let &completefunc = "{a -> 'abc'}"
  call feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')

  " Vim9 tests
  let lines =<< trim END
    vim9script

    # Test for using function()
    def MycompleteFunc1(findstart: number, base: string): any
      add(g:MycompleteFunc1_args, [findstart, base])
      return findstart ? 0 : []
    enddef
    set completefunc=function('MycompleteFunc1')
    new | only
    setline(1, 'one')
    g:MycompleteFunc1_args = []
    feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'one']], g:MycompleteFunc1_args)
    bw!

    # Test for using a lambda
    def LambdaComplete1(findstart: number, base: string): any
      add(g:LambdaComplete1_args, [findstart, base])
      return findstart ? 0 : []
    enddef
    &completefunc = '(a, b) => LambdaComplete1(a, b)'
    new | only
    setline(1, 'two')
    g:LambdaComplete1_args = []
    feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'two']], g:LambdaComplete1_args)
    bw!

    # Test for using a variable with a lambda expression
    var Fn: func = (findstart, base) => {
            add(g:LambdaComplete2_args, [findstart, base])
            return findstart ? 0 : []
        }
    &completefunc = string(Fn)
    new | only
    setline(1, 'three')
    g:LambdaComplete2_args = []
    feedkeys("A\<C-X>\<C-U>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'three']], g:LambdaComplete2_args)
    bw!
  END
  call CheckScriptSuccess(lines)

  " Using Vim9 lambda expression in legacy context should fail
  set completefunc=(a,\ b)\ =>\ g:MycompleteFunc2(a,\ b)
  new | only
  let g:MycompleteFunc2_args = []
  call assert_fails('call feedkeys("A\<C-X>\<C-U>\<Esc>", "x")', 'E117:')
  call assert_equal([], g:MycompleteFunc2_args)

  " cleanup
  delfunc MycompleteFunc1
  delfunc MycompleteFunc2
  delfunc MycompleteFunc3
  set completefunc&
  %bw!
endfunc

" Test for different ways of setting the 'omnifunc' option
func Test_omnifunc_callback()
  " Test for using a function()
  func MyomniFunc1(findstart, base)
    call add(g:MyomniFunc1_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set omnifunc=function('MyomniFunc1')
  new | only
  call setline(1, 'one')
  let g:MyomniFunc1_args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'one']], g:MyomniFunc1_args)
  bw!

  " Using a funcref variable to set 'omnifunc'
  let Fn = function('MyomniFunc1')
  let &omnifunc = string(Fn)
  new | only
  call setline(1, 'two')
  let g:MyomniFunc1_args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'two']], g:MyomniFunc1_args)
  call assert_fails('let &omnifunc = Fn', 'E729:')
  bw!

  " Test for using a funcref()
  func MyomniFunc2(findstart, base)
    call add(g:MyomniFunc2_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set omnifunc=funcref('MyomniFunc2')
  new | only
  call setline(1, 'three')
  let g:MyomniFunc2_args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'three']], g:MyomniFunc2_args)
  bw!

  " Using a funcref variable to set 'omnifunc'
  let Fn = funcref('MyomniFunc2')
  let &omnifunc = string(Fn)
  new | only
  call setline(1, 'four')
  let g:MyomniFunc2_args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'four']], g:MyomniFunc2_args)
  call assert_fails('let &omnifunc = Fn', 'E729:')
  bw!

  " Test for using a lambda function
  func MyomniFunc3(findstart, base)
    call add(g:MyomniFunc3_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set omnifunc={a,\ b\ ->\ MyomniFunc3(a,\ b)}
  new | only
  call setline(1, 'five')
  let g:MyomniFunc3_args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'five']], g:MyomniFunc3_args)
  bw!

  " Set 'omnifunc' to a lambda expression
  let &omnifunc = '{a, b -> MyomniFunc3(a, b)}'
  new | only
  call setline(1, 'six')
  let g:MyomniFunc3_args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'six']], g:MyomniFunc3_args)
  bw!

  " Set 'omnifunc' to a variable with a lambda expression
  let Lambda = {a, b -> MyomniFunc3(a, b)}
  let &omnifunc = string(Lambda)
  new | only
  call setline(1, 'seven')
  let g:MyomniFunc3_args = []
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'seven']], g:MyomniFunc3_args)
  call assert_fails('let &omnifunc = Lambda', 'E729:')
  bw!

  " Test for using a lambda function with incorrect return value
  let Lambda = {s -> strlen(s)}
  let &omnifunc = string(Lambda)
  new | only
  call setline(1, 'eight')
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
  bw!

  " Test for clearing the 'omnifunc' option
  set omnifunc=''
  set omnifunc&

  call assert_fails("set omnifunc=function('abc')", "E700:")
  call assert_fails("set omnifunc=funcref('abc')", "E700:")
  let &omnifunc = "{a -> 'abc'}"
  call feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')

  " Vim9 tests
  let lines =<< trim END
    vim9script

    # Test for using function()
    def MyomniFunc1(findstart: number, base: string): any
      add(g:MyomniFunc1_args, [findstart, base])
      return findstart ? 0 : []
    enddef
    set omnifunc=function('MyomniFunc1')
    new | only
    setline(1, 'one')
    g:MyomniFunc1_args = []
    feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'one']], g:MyomniFunc1_args)
    bw!

    # Test for using a lambda
    def MyomniFunc2(findstart: number, base: string): any
      add(g:MyomniFunc2_args, [findstart, base])
      return findstart ? 0 : []
    enddef
    &omnifunc = '(a, b) => MyomniFunc2(a, b)'
    new | only
    setline(1, 'two')
    g:MyomniFunc2_args = []
    feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'two']], g:MyomniFunc2_args)
    bw!

    # Test for using a variable with a lambda expression
    var Fn: func = (a, b) => MyomniFunc2(a, b)
    &omnifunc = string(Fn)
    new | only
    setline(1, 'three')
    g:MyomniFunc2_args = []
    feedkeys("A\<C-X>\<C-O>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'three']], g:MyomniFunc2_args)
    bw!
  END
  call CheckScriptSuccess(lines)

  " Using Vim9 lambda expression in legacy context should fail
  set omnifunc=(a,\ b)\ =>\ g:MyomniFunc2(a,\ b)
  new | only
  let g:MyomniFunc2_args = []
  call assert_fails('call feedkeys("A\<C-X>\<C-O>\<Esc>", "x")', 'E117:')
  call assert_equal([], g:MyomniFunc2_args)

  " cleanup
  delfunc MyomniFunc1
  delfunc MyomniFunc2
  delfunc MyomniFunc3
  set omnifunc&
  %bw!
endfunc

" Test for different ways of setting the 'thesaurusfunc' option
func Test_thesaurusfunc_callback()
  " Test for using a function()
  func MytsrFunc1(findstart, base)
    call add(g:MytsrFunc1_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set thesaurusfunc=function('MytsrFunc1')
  new | only
  call setline(1, 'one')
  let g:MytsrFunc1_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'one']], g:MytsrFunc1_args)
  bw!

  " Using a funcref variable to set 'thesaurusfunc'
  let Fn = function('MytsrFunc1')
  let &thesaurusfunc = string(Fn)
  new | only
  call setline(1, 'two')
  let g:MytsrFunc1_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'two']], g:MytsrFunc1_args)
  call assert_fails('let &thesaurusfunc = Fn', 'E729:')
  bw!

  " Test for using a funcref()
  func MytsrFunc2(findstart, base)
    call add(g:MytsrFunc2_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set thesaurusfunc=funcref('MytsrFunc2')
  new | only
  call setline(1, 'three')
  let g:MytsrFunc2_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'three']], g:MytsrFunc2_args)
  bw!

  " Using a funcref variable to set 'thesaurusfunc'
  let Fn = funcref('MytsrFunc2')
  let &thesaurusfunc = string(Fn)
  new | only
  call setline(1, 'four')
  let g:MytsrFunc2_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'four']], g:MytsrFunc2_args)
  call assert_fails('let &thesaurusfunc = Fn', 'E729:')
  bw!

  " Test for using a lambda function
  func MytsrFunc3(findstart, base)
    call add(g:MytsrFunc3_args, [a:findstart, a:base])
    return a:findstart ? 0 : []
  endfunc
  set thesaurusfunc={a,\ b\ ->\ MytsrFunc3(a,\ b)}
  new | only
  call setline(1, 'five')
  let g:MytsrFunc3_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'five']], g:MytsrFunc3_args)
  bw!

  " Set 'thesaurusfunc' to a lambda expression
  let &thesaurusfunc = '{a, b -> MytsrFunc3(a, b)}'
  new | only
  call setline(1, 'six')
  let g:MytsrFunc3_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'six']], g:MytsrFunc3_args)
  bw!

  " Set 'thesaurusfunc' to a variable with a lambda expression
  let Lambda = {a, b -> MytsrFunc3(a, b)}
  let &thesaurusfunc = string(Lambda)
  new | only
  call setline(1, 'seven')
  let g:MytsrFunc3_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  call assert_equal([[1, ''], [0, 'seven']], g:MytsrFunc3_args)
  call assert_fails('let &thesaurusfunc = Lambda', 'E729:')
  bw!

  " Test for using a lambda function with incorrect return value
  let Lambda = {s -> strlen(s)}
  let &thesaurusfunc = string(Lambda)
  new | only
  call setline(1, 'eight')
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
  bw!

  " Test for clearing the 'thesaurusfunc' option
  set thesaurusfunc=''
  set thesaurusfunc&

  call assert_fails("set thesaurusfunc=function('abc')", "E700:")
  call assert_fails("set thesaurusfunc=funcref('abc')", "E700:")
  let &thesaurusfunc = "{a -> 'abc'}"
  call feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')

  " Vim9 tests
  let lines =<< trim END
    vim9script

    # Test for using function()
    def MytsrFunc1(findstart: number, base: string): any
      add(g:MytsrFunc1_args, [findstart, base])
      return findstart ? 0 : []
    enddef
    set thesaurusfunc=function('MytsrFunc1')
    new | only
    setline(1, 'one')
    g:MytsrFunc1_args = []
    feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'one']], g:MytsrFunc1_args)
    bw!

    # Test for using a lambda
    def MytsrFunc2(findstart: number, base: string): any
      add(g:MytsrFunc2_args, [findstart, base])
      return findstart ? 0 : []
    enddef
    &thesaurusfunc = '(a, b) => MytsrFunc2(a, b)'
    new | only
    setline(1, 'two')
    g:MytsrFunc2_args = []
    feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'two']], g:MytsrFunc2_args)
    bw!

    # Test for using a variable with a lambda expression
    var Fn: func = (a, b) => MytsrFunc2(a, b)
    &thesaurusfunc = string(Fn)
    new | only
    setline(1, 'three')
    g:MytsrFunc2_args = []
    feedkeys("A\<C-X>\<C-T>\<Esc>", 'x')
    assert_equal([[1, ''], [0, 'three']], g:MytsrFunc2_args)
    bw!
  END
  call CheckScriptSuccess(lines)

  " Using Vim9 lambda expression in legacy context should fail
  set thesaurusfunc=(a,\ b)\ =>\ g:MytsrFunc2(a,\ b)
  new | only
  let g:MytsrFunc2_args = []
  call assert_fails('call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")', 'E117:')
  call assert_equal([], g:MytsrFunc2_args)
  bw!

  " Use a buffer-local value and a global value
  func MytsrFunc4(findstart, base)
    call add(g:MytsrFunc4_args, [a:findstart, a:base])
    return a:findstart ? 0 : ['sunday']
  endfunc
  set thesaurusfunc&
  setlocal thesaurusfunc=function('MytsrFunc4')
  call setline(1, 'sun')
  let g:MytsrFunc4_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")
  call assert_equal('sunday', getline(1))
  call assert_equal([[1, ''], [0, 'sun']], g:MytsrFunc4_args)
  new
  call setline(1, 'sun')
  let g:MytsrFunc4_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")
  call assert_equal('sun', getline(1))
  call assert_equal([], g:MytsrFunc4_args)
  set thesaurusfunc=function('MytsrFunc1')
  wincmd w
  call setline(1, 'sun')
  let g:MytsrFunc4_args = []
  call feedkeys("A\<C-X>\<C-T>\<Esc>", "x")
  call assert_equal('sunday', getline(1))
  call assert_equal([[1, ''], [0, 'sun']], g:MytsrFunc4_args)

  " cleanup
  set thesaurusfunc&
  delfunc MytsrFunc1
  delfunc MytsrFunc2
  delfunc MytsrFunc3
  delfunc MytsrFunc4
  %bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
