export QT_XCB_GL_INTEGRATION=xcb_egl
export KWIN_OPENGL_INTERFACE=egl
export GST_GL_PLATFORM=egl    # this is not related to kwin, but it's useful
export QTWEBENGINE_CHROMIUM_FLAGS="--use-gl=angle --use-angle=vulkan"
