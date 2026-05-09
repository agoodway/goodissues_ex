// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/good_issues"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const Hooks = {
  ...colocatedHooks,
  Modal: {
    mounted() {
      if (this.el.dataset.show === "true" && !this.el.open) {
        this.el.showModal()
        this.el.classList.add("modal-opening")
        requestAnimationFrame(() => this.el.classList.remove("modal-opening"))
      }
      this.el._cancelHandler = (e) => {
        e.preventDefault()
        this.closeWithAnimation()
      }
      this.el.addEventListener("cancel", this.el._cancelHandler)
    },
    beforeUpdate() {
      this._wasOpen = this.el.open
    },
    updated() {
      // If LV's diff stripped the `open` attribute that showModal() set,
      // put it back without calling showModal() again — calling showModal()
      // re-traps focus to the first focusable element in the dialog.
      if (this._wasOpen && !this.el.hasAttribute("open")) {
        this.el.setAttribute("open", "")
      }
      const shouldShow = this.el.dataset.show === "true"
      if (!shouldShow && this.el.open) {
        this.closeWithAnimation()
      }
    },
    destroyed() {
      if (this.el._cancelHandler) {
        this.el.removeEventListener("cancel", this.el._cancelHandler)
        delete this.el._cancelHandler
      }
      if (this.el.open) this.el.close()
    },
    closeWithAnimation() {
      const modal = this.el
      if (!modal.open || modal.classList.contains("modal-closing")) return
      modal.classList.add("modal-closing")
      setTimeout(() => {
        modal.classList.remove("modal-closing")
        if (modal.open) modal.close()
      }, 200)
    }
  },
  CopyToClipboard: {
    mounted() {
      this.el.addEventListener("click", () => {
        const targetId = this.el.dataset.copyTarget
        const targetEl = document.getElementById(targetId)
        if (targetEl) {
          navigator.clipboard.writeText(targetEl.value).then(() => {
            const originalText = this.el.innerHTML
            this.el.innerHTML = '<span class="loading loading-spinner loading-xs"></span> Copied!'
            setTimeout(() => {
              this.el.innerHTML = originalText
            }, 2000)
          })
        }
      })
    }
  },
  MobileSidebar: {
    mounted() {
      const sidebar = document.getElementById("sidebar")
      const backdrop = document.getElementById("sidebar-backdrop")

      const toggleSidebar = () => {
        const isOpen = sidebar.classList.contains("sidebar-open")
        if (isOpen) {
          // Close sidebar
          sidebar.classList.remove("sidebar-open")
          backdrop.classList.add("hidden")
          document.body.style.overflow = ""
        } else {
          // Open sidebar
          sidebar.classList.add("sidebar-open")
          backdrop.classList.remove("hidden")
          document.body.style.overflow = "hidden"
        }
      }

      // Listen for toggle events
      window.addEventListener("toggle-sidebar", toggleSidebar)

      // Close sidebar on navigation (for LiveView)
      this.handleEvent && this.handleEvent("close-sidebar", () => {
        sidebar.classList.remove("sidebar-open")
        backdrop.classList.add("hidden")
        document.body.style.overflow = ""
      })

      // Clean up on destroy
      this.destroy = () => {
        window.removeEventListener("toggle-sidebar", toggleSidebar)
      }
    },
    destroyed() {
      if (this.destroy) this.destroy()
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Modal event handlers for terminal-style modals
window.addEventListener("modal:open", e => {
  const modal = e.target
  modal.showModal()

  // Add opening class for animations
  modal.classList.add("modal-opening")
  requestAnimationFrame(() => {
    modal.classList.remove("modal-opening")
  })

  // Intercept native ESC/cancel to add closing animation
  const handleCancel = (event) => {
    event.preventDefault()
    closeModalWithAnimation(modal)
  }
  modal._cancelHandler = handleCancel
  modal.addEventListener("cancel", handleCancel)
})

window.addEventListener("modal:close", e => {
  const modal = e.target
  closeModalWithAnimation(modal)
})

function closeModalWithAnimation(modal) {
  if (!modal.open || modal.classList.contains("modal-closing")) return

  // Clean up cancel handler
  if (modal._cancelHandler) {
    modal.removeEventListener("cancel", modal._cancelHandler)
    delete modal._cancelHandler
  }

  // Add closing animation
  modal.classList.add("modal-closing")

  // Wait for animation to complete before closing
  setTimeout(() => {
    modal.classList.remove("modal-closing")
    modal.close()
  }, 200)
}

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
