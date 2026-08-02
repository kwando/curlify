watch_tests:
    watchexec --clear --debounce 200ms -e gleam gleam test
watch_docs:
    watchexec --clear --debounce 2s -e gleam gleam docs build
