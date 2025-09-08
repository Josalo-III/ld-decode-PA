if(Qwt_FOUND)
  return()
endif()

if(DEFINED QWT_ROOT AND NOT DEFINED Qwt_ROOT)
  set(Qwt_ROOT "${QWT_ROOT}")
endif()

set(_QWT_HINTS)
if(Qwt_ROOT)
  list(APPEND _QWT_HINTS "${Qwt_ROOT}" "${Qwt_ROOT}/lib" "${Qwt_ROOT}/Library/Frameworks" "${Qwt_ROOT}/Frameworks")
endif()
# Always ensure our known prefix first
list(INSERT _QWT_HINTS 0 /usr/local/qwt-6.3.0/lib /usr/local/qwt-6.3.0)

set(QWT_LIBRARY "")
set(QWT_INCLUDE_DIRS "")

# Framework search
foreach(_h IN LISTS _QWT_HINTS)
  if(EXISTS "${_h}/qwt.framework")
    set(_fw "${_h}/qwt.framework")
    if(EXISTS "${_fw}/Versions/6/Headers")
      list(APPEND QWT_INCLUDE_DIRS "${_fw}/Versions/6/Headers")
    elseif(EXISTS "${_fw}/Versions/Current/Headers")
      list(APPEND QWT_INCLUDE_DIRS "${_fw}/Versions/Current/Headers")
    elseif(EXISTS "${_fw}/Headers")
      list(APPEND QWT_INCLUDE_DIRS "${_fw}/Headers")
    endif()

    if(EXISTS "${_fw}/Versions/6/qwt")
      set(QWT_LIBRARY "${_fw}/Versions/6/qwt")
    elseif(EXISTS "${_fw}/qwt")
      set(QWT_LIBRARY "${_fw}/qwt")
    endif()

    if(QWT_LIBRARY AND QWT_INCLUDE_DIRS)
      break()
    endif()
  endif()
endforeach()

# Fallback (classic lib) not needed; skip unless you want:
# if(NOT QWT_LIBRARY) find_library(QWT_LIBRARY NAMES qwt) endif()

# Version (optional)
if(QWT_INCLUDE_DIRS AND EXISTS "${QWT_INCLUDE_DIRS}/qwt_global.h")
  file(STRINGS "${QWT_INCLUDE_DIRS}/qwt_global.h" _v REGEX "#define[ \t]+QWT_VERSION_STR")
  if(_v MATCHES "#define[ \t]+QWT_VERSION_STR[ \t]+\"([0-9\\.]+)\"")
    set(QWT_VERSION "${CMAKE_MATCH_1}")
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Qwt REQUIRED_VARS QWT_LIBRARY QWT_INCLUDE_DIRS VERSION_VAR QWT_VERSION)

if(Qwt_FOUND AND NOT TARGET Qwt::Qwt)
  add_library(Qwt::Qwt INTERFACE IMPORTED)
  set_target_properties(Qwt::Qwt PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${QWT_INCLUDE_DIRS}"
    INTERFACE_LINK_LIBRARIES "${QWT_LIBRARY}"
  )
  message(STATUS "Using Qwt at: ${QWT_LIBRARY}")
  message(STATUS "Qwt includes: ${QWT_INCLUDE_DIRS}")
endif()

mark_as_advanced(QWT_LIBRARY QWT_INCLUDE_DIRS)