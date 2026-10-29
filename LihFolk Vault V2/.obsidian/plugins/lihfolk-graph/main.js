// LihFolk Graph: tint every graph link with its note's colour group (rainbow threads).
// Works with the core graph view; the link base colour is white in graph-cosmic.css so the tint shows true colour.
const { Plugin } = require("obsidian");

const WHITE = 0xffffff;

module.exports = class LihFolkGraph extends Plugin {
  onload() {
    this.patched = null;
    this.registerEvent(this.app.workspace.on("layout-change", () => this.patchSoon()));
    this.app.workspace.onLayoutReady(() => this.patchSoon());
    // on startup the graph can build its links long after layout-ready, so keep trying until patched
    this.registerInterval(window.setInterval(() => this.patch(), 2000));
  }

  patchSoon() {
    // the renderer creates its links a moment after the view opens
    for (const delay of [300, 1500]) window.setTimeout(() => this.patch(), delay);
  }

  patch() {
    if (this.patched) return;
    for (const leaf of this.app.workspace.getLeavesOfType("graph").concat(this.app.workspace.getLeavesOfType("localgraph"))) {
      const link = leaf.view && leaf.view.renderer && leaf.view.renderer.links && leaf.view.renderer.links[0];
      if (!link) continue;
      const proto = Object.getPrototypeOf(link);
      if (proto.__lihfolkOriginalRender) { this.patched = proto; return; }
      const original = proto.render;
      proto.__lihfolkOriginalRender = original;
      proto.render = function () {
        const out = original.apply(this, arguments);
        const src = this.source && this.source.color && this.source.color.rgb;
        const dst = this.target && this.target.color && this.target.color.rgb;
        const tint = src != null && src !== WHITE ? src : dst;
        if (tint != null && this.line) this.line.tint = tint;
        return out;
      };
      this.patched = proto;
      leaf.view.renderer.changed && leaf.view.renderer.changed();
      return;
    }
  }

  onunload() {
    if (this.patched && this.patched.__lihfolkOriginalRender) {
      this.patched.render = this.patched.__lihfolkOriginalRender;
      delete this.patched.__lihfolkOriginalRender;
    }
  }
};
