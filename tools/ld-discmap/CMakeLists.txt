add_executable(ld-discmap
    discmap.cpp
    discmapper.cpp
    frame.cpp
    main.cpp
)

target_link_libraries(ld-discmap PRIVATE Qt6::Core lddecode-library)

install(TARGETS ld-discmap)
