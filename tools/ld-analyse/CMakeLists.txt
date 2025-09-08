# GUI tool: ld-analyse

# For M_PI constant
add_compile_definitions(_USE_MATH_DEFINES)

set(ld-analyse_SOURCES
    blacksnranalysisdialog.cpp blacksnranalysisdialog.ui
    busydialog.cpp busydialog.ui
    closedcaptionsdialog.cpp closedcaptionsdialog.ui
    main.cpp
    mainwindow.cpp mainwindow.ui
    oscilloscopedialog.cpp oscilloscopedialog.ui
    vectorscopedialog.cpp vectorscopedialog.ui
    aboutdialog.cpp aboutdialog.ui
    videoparametersdialog.cpp videoparametersdialog.ui
    chromadecoderconfigdialog.cpp chromadecoderconfigdialog.ui
    tbcsource.cpp
    vbidialog.cpp vbidialog.ui
    configuration.cpp
    dropoutanalysisdialog.cpp dropoutanalysisdialog.ui
    visibledropoutanalysisdialog.cpp visibledropoutanalysisdialog.ui
    whitesnranalysisdialog.cpp whitesnranalysisdialog.ui
)

qt_add_resources(ld-analyse_SOURCES ld-analyse-resources.qrc)

# Option to control bundling of the Qwt framework
option(BUNDLE_QWT_FRAMEWORK "Bundle a prebuilt Qwt.framework inside ld-analyse.app (macOS)" ON)

# Allow user override; leave blank by default to force explicit setting or detection
set(QWT_FRAMEWORK_PATH "" CACHE PATH "Path to Qwt.framework (directory ending in Qwt.framework or qwt.framework)")

# --- Qwt Framework (macOS) detection and imported target ---
if(APPLE AND BUNDLE_QWT_FRAMEWORK)
    # If user did not specify, try a few common locations
    if(NOT QWT_FRAMEWORK_PATH)
        foreach(_probe
            /usr/local/qwt-6.3.0/lib/Qwt.framework
            /usr/local/qwt-6.3.0/lib/qwt.framework
            /usr/local/lib/Qwt.framework
            /usr/local/lib/qwt.framework
            /opt/local/libexec/qwt*/lib/Qwt.framework
            )
            if(EXISTS "${_probe}")
                set(QWT_FRAMEWORK_PATH "${_probe}")
                break()
            endif()
        endforeach()
    endif()

    if(NOT QWT_FRAMEWORK_PATH OR NOT EXISTS "${QWT_FRAMEWORK_PATH}")
        message(FATAL_ERROR "QWT_FRAMEWORK_PATH not set or does not exist. Set -DQWT_FRAMEWORK_PATH=/absolute/path/to/Qwt.framework")
    endif()

    # Normalize path (remove trailing slash, resolve symlinks)
    get_filename_component(QWT_FRAMEWORK_PATH "${QWT_FRAMEWORK_PATH}" REALPATH)

    # Candidate binaries (support both lowercase and capitalized; flat vs Versions)
    set(_QWT_BIN_CANDIDATES
        "${QWT_FRAMEWORK_PATH}/qwt"
        "${QWT_FRAMEWORK_PATH}/Qwt"
        "${QWT_FRAMEWORK_PATH}/Versions/A/qwt"
        "${QWT_FRAMEWORK_PATH}/Versions/A/Qwt"
        "${QWT_FRAMEWORK_PATH}/Versions/Current/qwt"
        "${QWT_FRAMEWORK_PATH}/Versions/Current/Qwt"
    )
    set(QWT_FRAMEWORK_BINARY "")
    foreach(cand IN LISTS _QWT_BIN_CANDIDATES)
        if(EXISTS "${cand}")
            set(QWT_FRAMEWORK_BINARY "${cand}")
            break()
        endif()
    endforeach()
    if(QWT_FRAMEWORK_BINARY STREQUAL "")
        message(FATAL_ERROR "Could not locate Qwt binary within framework: ${QWT_FRAMEWORK_PATH}")
    endif()

    # Headers candidates
    set(_QWT_HEADERS_CANDIDATES
        "${QWT_FRAMEWORK_PATH}/Headers"
        "${QWT_FRAMEWORK_PATH}/Versions/A/Headers"
        "${QWT_FRAMEWORK_PATH}/Versions/Current/Headers"
    )
    set(QWT_FRAMEWORK_HEADERS "")
    foreach(hcand IN LISTS _QWT_HEADERS_CANDIDATES)
        if(EXISTS "${hcand}/qwt_global.h")
            set(QWT_FRAMEWORK_HEADERS "${hcand}")
            break()
        endif()
    endforeach()
    if(QWT_FRAMEWORK_HEADERS STREQUAL "")
        message(FATAL_ERROR "Could not find qwt_global.h under: ${QWT_FRAMEWORK_PATH}")
    endif()

    # Create imported framework target only once
    if(NOT TARGET Qwt::Qwt)
        add_library(Qwt::Qwt SHARED IMPORTED)
        set_target_properties(Qwt::Qwt PROPERTIES
            IMPORTED_LOCATION "${QWT_FRAMEWORK_BINARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${QWT_FRAMEWORK_HEADERS}"
            FRAMEWORK TRUE
        )
    endif()
endif()

# Executable definition
if(WIN32)
    set(APP_ICON_RESOURCE_WINDOWS "${CMAKE_CURRENT_SOURCE_DIR}/appicon.rc")
    add_executable(ld-analyse
        ${ld-analyse_SOURCES}
        ${APP_ICON_RESOURCE_WINDOWS})
elseif(APPLE)
    add_executable(ld-analyse MACOSX_BUNDLE
        ${ld-analyse_SOURCES})
else()
    add_executable(ld-analyse
        ${ld-analyse_SOURCES})
endif()

if(APPLE)
    set(_SRC_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist")
    if(NOT EXISTS "${_SRC_INFO_PLIST}")
        message(FATAL_ERROR "ld-analyse: Info.plist not found at ${_SRC_INFO_PLIST}")
    endif()
    message(STATUS "ld-analyse: Found Info.plist at ${_SRC_INFO_PLIST}")
    configure_file("${_SRC_INFO_PLIST}" "${CMAKE_CURRENT_BINARY_DIR}/Info.plist" COPYONLY)
    set_target_properties(ld-analyse PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist")
endif()

# Include directories (legacy pieces — if building without framework, QWT_INCLUDE_DIR may be set elsewhere)
target_include_directories(ld-analyse PRIVATE
    ${FFTW_INCLUDE_DIR}
)

# Link libraries
if(APPLE AND BUNDLE_QWT_FRAMEWORK)
    target_link_libraries(ld-analyse PRIVATE
        Qt::Core Qt::Gui Qt::Widgets
        Qwt::Qwt
        ${FFTW_LIBRARY}
        lddecode-library lddecode-chroma
    )
else()
    target_link_libraries(ld-analyse PRIVATE
        Qt::Core Qt::Gui Qt::Widgets
        ${QWT_LIBRARY}            # Non-framework (if found earlier)
        ${FFTW_LIBRARY}
        lddecode-library lddecode-chroma
    )
endif()

if(WIN32)
    target_compile_definitions(ld-analyse PRIVATE
        NOMINMAX
        QUSB_LIBRARY
    )
    set_property(TARGET ld-analyse PROPERTY WIN32_EXECUTABLE true)
endif()

# macOS specific RPATH & bundle tuning
if(APPLE)
    set(CMAKE_MACOSX_RPATH ON)
    # Add both executable and loader path forms, future-proof for plugins
    set_target_properties(ld-analyse PROPERTIES
        INSTALL_RPATH "@executable_path/../Frameworks;@loader_path/../Frameworks"
        BUILD_WITH_INSTALL_RPATH OFF
    )
endif()

# Install rules
if(UNIX AND NOT APPLE)
    install(TARGETS ld-analyse)
elseif(APPLE)
    install(TARGETS ld-analyse BUNDLE DESTINATION .)

    if(BUNDLE_QWT_FRAMEWORK)
        # Copy framework into bundle and patch paths
        install(CODE "
            set(app \"\$<TARGET_FILE:ld-analyse>\")
            get_filename_component(app_dir \"\${app}\" DIRECTORY)
            get_filename_component(contents_dir \"\${app_dir}\" DIRECTORY)
            # contents_dir = .../ld-analyse.app/Contents
            set(frameworks_dir \"\${contents_dir}/Frameworks\")
            file(MAKE_DIRECTORY \"\${frameworks_dir}\")

            message(STATUS \"Bundling Qwt framework: ${QWT_FRAMEWORK_PATH}\")
            execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy_directory
                \"${QWT_FRAMEWORK_PATH}\" \"\${frameworks_dir}/Qwt.framework\" ERROR_QUIET)

            # Determine binary naming inside copied framework
            set(_QWT_BIN_CAND
                \"\${frameworks_dir}/Qwt.framework/Qwt\"
                \"\${frameworks_dir}/Qwt.framework/qwt\"
                \"\${frameworks_dir}/Qwt.framework/Versions/A/Qwt\"
                \"\${frameworks_dir}/Qwt.framework/Versions/A/qwt\"
            )
            set(_qwt_bin \"\")
            foreach(b IN LISTS _QWT_BIN_CAND)
                if(EXISTS \"\${b}\")
                    set(_qwt_bin \"\${b}\")
                    break()
                endif()
            endforeach()

            if(NOT _qwt_bin)
                message(WARNING \"Could not find Qwt binary after copying framework.\")
            else()
                # Set a clean id using @rpath
                execute_process(COMMAND install_name_tool -id @rpath/Qwt.framework/Qwt \"\${_qwt_bin}\" ERROR_QUIET)
                # Patch main executable references (both lowercase and uppercase variants)
                execute_process(COMMAND install_name_tool
                    -change ${QWT_FRAMEWORK_PATH}/Qwt @rpath/Qwt.framework/Qwt \"\${app}\" ERROR_QUIET)
                execute_process(COMMAND install_name_tool
                    -change ${QWT_FRAMEWORK_PATH}/qwt @rpath/Qwt.framework/Qwt \"\${app}\" ERROR_QUIET)
                execute_process(COMMAND install_name_tool
                    -change ${QWT_FRAMEWORK_PATH}/Versions/A/Qwt @rpath/Qwt.framework/Qwt \"\${app}\" ERROR_QUIET)
                execute_process(COMMAND install_name_tool
                    -change ${QWT_FRAMEWORK_PATH}/Versions/A/qwt @rpath/Qwt.framework/Qwt \"\${app}\" ERROR_QUIET)
            endif()
        ")
    endif()
else()
    install(TARGETS ld-analyse)
endif()