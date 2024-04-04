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

func Test_multibyte()
  " using an invalid character should not cause a crash
  set wic
  call assert_fails('tc ˚ççç¶*', 'E344:')
  set nowic
endfunc


" vim: shiftwidth=2 sts=2 expandtab
