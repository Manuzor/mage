cmake_minimum_required(VERSION 3.2)

project("dependencies sample (cmake)")

include_directories(.)

add_library(foo STATIC foo/foo.h foo/foo.cpp)

add_library(bar STATIC bar/bar.h bar/bar.cpp)
target_link_libraries(bar foo)

add_executable(baz baz/baz.cpp)
target_link_libraries(baz bar)
