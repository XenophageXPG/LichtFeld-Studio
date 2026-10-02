vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mikke89/RmlUi
    REF ${VERSION}
    SHA512 f08c126d3727850724072fb88b1c95cb6c5dcc160082bffcba42d2236950b651e39d71f7c0eecf5a5a047f68ad5cc7f1968d2334c5b72c019d2aefb3fb55e246
    HEAD_REF master
    PATCHES
        add-itlib-and-robin-hood.patch
        skip-custom-find-modules.patch
        context-mouse-button-cancel.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        lua             RMLUI_LUA_BINDINGS
        svg             RMLUI_SVG_PLUGIN
        lottie          RMLUI_LOTTIE_PLUGIN
)

if("freetype" IN_LIST FEATURES)
    set(RMLUI_FONT_ENGINE "freetype")
else()
    set(RMLUI_FONT_ENGINE "none")
endif()

# Remove built-in third-party dependencies (itlib and robin-hood), instead we use vcpkg ports.
file(REMOVE_RECURSE "${SOURCE_PATH}/Include/RmlUi/Core/Containers")

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DRMLUI_FONT_ENGINE=${RMLUI_FONT_ENGINE}"
        "-DRMLUI_COMPILER_OPTIONS=OFF"
        "-DRMLUI_INSTALL_RUNTIME_DEPENDENCIES=OFF"
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/RmlUi)
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    # ObserverPtr<T> is declared as `class RMLUICORE_API ObserverPtr` (6.2) /
    # `class RMLUICORE_API ObserverPtr<T>` (6.1), but its default constructor and
    # copy assignment operator are defined inline in the header with no export
    # annotation of their own. Under MSVC, marking a class __declspec(dllimport)
    # applies the import attribute to every member function, including those
    # inline definitions, so lfs_visualizer.dll expects import thunks for
    # `ObserverPtr<T>::ObserverPtr()` and `ObserverPtr<T>::operator=(const
    # ObserverPtr<T>&)`. The static RmlUi library never emits those thunks --
    # only the rvalue overloads survive, because they are explicitly instantiated
    # in ObserverPtr.cpp. Result: LNK2019/LNK1120 on three externals.
    #
    # Dropping the dllimport attribute from ObserverPtr (and only ObserverPtr)
    # makes both sides agree on external linkage for a static build. This is the
    # same approach already used below for the RMLUI_STATIC_LIB headers.
    set(_rmlui_observer_header "${CURRENT_PACKAGES_DIR}/include/RmlUi/Core/ObserverPtr.h")
    if(EXISTS "${_rmlui_observer_header}")
        file(READ "${_rmlui_observer_header}" _rmlui_observer_content)
        string(REGEX REPLACE
            "class RMLUICORE_API ObserverPtr"
            "class ObserverPtr"
            _rmlui_observer_content "${_rmlui_observer_content}")
        file(WRITE "${_rmlui_observer_header}" "${_rmlui_observer_content}")
    endif()

    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/RmlUi/Core/Header.h"
        "#if !defined RMLUI_STATIC_LIB"
        "#if 0"
    )
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/RmlUi/Debugger/Header.h"
        "#if !defined RMLUI_STATIC_LIB"
        "#if 0"
    )
    if ("lua" IN_LIST FEATURES)
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/RmlUi/Lua/Header.h"
            "#if !defined RMLUI_STATIC_LIB"
            "#if 0"
        )
    endif()
endif()

configure_file("${CMAKE_CURRENT_LIST_DIR}/usage" "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" COPYONLY)
vcpkg_install_copyright(
    FILE_LIST
    "${SOURCE_PATH}/LICENSE.txt"
    "${SOURCE_PATH}/Source/Debugger/LICENSE.txt"
)
