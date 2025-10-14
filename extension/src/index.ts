import { IRenderMime } from '@jupyterlab/rendermime-interfaces';
import { Widget } from '@lumino/widgets';
import { instance as VizInstance } from '@viz-js/viz';

/**
 * The MIME type for Graphviz DOT files.
 */
const MIME_TYPE = 'application/vnd.graphviz.dot';

/**
 * The class name added to the extension.
 */
const CLASS_NAME = 'mimerenderer-graphviz-dot';

/**
 * A promise that resolves to a Viz.js instance.
 * We do this at the module level to avoid re-initializing the WASM module
 * for every new widget.
 */
const vizPromise = VizInstance();

/**
 * A widget for rendering Graphviz DOT files.
 */
export class GraphvizWidget extends Widget implements IRenderMime.IRenderer {
  /**
   * Construct a new output widget.
   */
  constructor(options: IRenderMime.IRendererOptions) {
    super();
    this._mimeType = options.mimeType;
    this.addClass(CLASS_NAME);
  }

  /**
   * Render DOT into this widget's node.
   */
  async renderModel(model: IRenderMime.IMimeModel): Promise<void> {
    const dotData = model.data[this._mimeType] as string;

    // Clear any previous content
    this.node.textContent = '';

    try {
      const viz = await vizPromise;
      const svgElement = viz.renderSVGElement(dotData);
      this.node.appendChild(svgElement);
    } catch (error) {
      console.error('Failed to render Graphviz DOT:', error);
      const pre = document.createElement('pre');
      pre.textContent = `Error rendering Graphviz DOT graph:\n${error}`;
      this.node.appendChild(pre);
    }
  }

  private _mimeType: string;
}

/**
 * A mime renderer factory for DOT data.
 */
export const rendererFactory: IRenderMime.IRendererFactory = {
  safe: true,
  mimeTypes: [MIME_TYPE],
  createRenderer: options => new GraphvizWidget(options)
};

/**
 * Extension definition.
 */
const extension: IRenderMime.IExtension = {
  id: '@jupyterlab-examples/graphviz-dot-renderer:plugin',
  rendererFactory,
  rank: 100, // Give it a higher rank to take precedence over plain text
  dataType: 'string',
  fileTypes: [
    {
      name: 'graphviz-dot',
      extensions: ['.dot', '.gv'],
      fileFormat: 'text',
      mimeTypes: [MIME_TYPE]
    }
  ],
  documentWidgetFactoryOptions: {
    name: 'Graphviz DOT Viewer',
    primaryFileType: 'graphviz-dot',
    fileTypes: ['graphviz-dot'],
    defaultFor: ['graphviz-dot']
  }
};

export default extension;
