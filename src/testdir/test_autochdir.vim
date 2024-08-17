" Test 'autochdir' behavior

source check.vim
CheckOption autochdir

func Test_set_filename()
  let cwd = getcwd()
  call test_autochdir()
  set acd

  let s:li = []
  autocmd DirChanged auto call add(s:li, "autocd")
  autocmd DirChanged auto call add(s:li, expand("<afile>"))

  new
  w samples/Xtest
  call assert_equal("Xtest", expand('%'))
  call assert_equal("samples", substitute(getcwd(), '.*/\(\k*\)', '\1', ''))
  call assert_equal(["autocd", getcwd()], s:li)

  bwipe!
  au! DirChanged
  set noacd
  call chdir(cwd)
  call delete('samples/Xtest')
endfunc

func Test_set_filename_other_window()
  call ch_logfile('logfile', 'w')
  let cwd = getcwd()
  call test_autochdir()
  call mkdir('Xa')
  call mkdir('Xb')
  call mkdir('Xc')
  try
    args Xa/aaa.txt Xb/bbb.txt
    set acd
    let winid = win_getid()
    snext
    call assert_equal('Xb', substitute(getcwd(), '.*/\([^/]*\)$', '\1', ''))
    call win_execute(winid, 'file ' .. cwd .. '/Xc/ccc.txt')
    call assert_equal('Xb', substitute(getcwd(), '.*/\([^/]*\)$', '\1', ''))
  finally
    set noacd
    call chdir(cwd)
    call delete('Xa', 'rf')
    call delete('Xb', 'rf')
    call delete('Xc', 'rf')
    bwipe! aaa.txt
    bwipe! bbb.txt
    bwipe! ccc.txt
  endtry
endfunc

func Test_verbose_pwd()
  let cwd = getcwd()
  call test_autochdir()

  edit global.txt
  call assert_match('\[global\].*testdir$', execute('verbose pwd'))

  call mkdir('Xautodir')
  split Xautodir/local.txt
  lcd Xautodir
  call assert_match('\[window\].*testdir[/\\]Xautodir', execute('verbose pwd'))

  set acd
  wincmd w
  call assert_match('\[autochdir\].*testdir$', execute('verbose pwd'))
  execute 'lcd' cwd
  call assert_match('\[window\].*testdir$', execute('verbose pwd'))
  execute 'tcd' cwd
  call assert_match('\[tabpage\].*testdir$', execute('verbose pwd'))
  execute 'cd' cwd
  call assert_match('\[global\].*testdir$', execute('verbose pwd'))
  edit
  call assert_match('\[autochdir\].*testdir$', execute('verbose pwd'))
  wincmd w
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  set noacd
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  wincmd w
  call assert_match('\[autochdir\].*testdir[/\\]Xautodir', execute('verbose pwd'))
  execute 'cd' cwd
  call assert_match('\[global\].*testdir', execute('verbose pwd'))
  wincmd w
  call assert_match('\[window\].*testdir[/\\]Xautodir', execute('verbose pwd'))

  bwipe!
  call chdir(cwd)
  call delete('Xautodir', 'rf')
endfunc

func Test_multibyte()
  " using an invalid character should not cause a crash
  set wic
  call assert_fails('tc ˚ççç¶*', 'E344:')
  set nowic
endfunc


" vim: shiftwidth=2 sts=2 expandtab
