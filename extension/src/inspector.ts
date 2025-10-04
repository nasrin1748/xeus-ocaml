import { JupyterFrontEnd, ILabShell } from '@jupyterlab/application';
import { IInspector } from '@jupyterlab/inspector';
import { IRenderMimeRegistry, MimeModel } from '@jupyterlab/rendermime';
import { Signal } from '@lumino/signaling';
import { ReadonlyJSONObject } from '@lumino/coreutils';

/**
 * Sets up the logic to control the Inspector panel from a command.
 *
 * @param app The JupyterFrontEnd application instance.
 * @param inspectorManager The inspector service.
 * @param rendermime The rendermime service.
 * @param labShell The application shell.
 */
export function setupInspectorControl(
  app: JupyterFrontEnd,
  inspectorManager: IInspector,
  rendermime: IRenderMimeRegistry,
  labShell: ILabShell
): void {
  let originalInspectorSource: IInspector.IInspectable | null = null;
  let isCustomSourceActive = false;

  // 1. Create the source object with null placeholders for the signals.
  const source: IInspector.IInspectable = {
    inspected: null as any,
    cleared: null as any,
    disposed: null as any,
    isDisposed: false,
    standby: false,
    onEditorChange: () => {}
  };

  // 2. Now that the `source` object exists, create the signals,
  //    passing `source` itself as the sender.
  source.inspected = new Signal(source);
  source.cleared = new Signal(source);
  source.disposed = new Signal(source);

  async function showCustomHelp(data: ReadonlyJSONObject) {
    if (!isCustomSourceActive) {
      originalInspectorSource = inspectorManager.source;
    }
    isCustomSourceActive = true;
    inspectorManager.source = source;

    const model = new MimeModel({ data });
    const mimeType = rendermime.preferredMimeType(data, 'any');
    if (!mimeType) {
      return;
    }
    const renderer = rendermime.createRenderer(mimeType);
    await renderer.renderModel(model);
    (source.inspected as Signal<any, IInspector.IInspectorUpdate>).emit({
      content: renderer
    });
  }

  app.commands.addCommand('inspector:show-custom-help', {
    label: 'Show Custom Help in Inspector',
    execute: async args => {
      const data = args.data as ReadonlyJSONObject;
      if (data) {
        await showCustomHelp(data);
      }
    }
  });

  labShell.activeChanged.connect(() => {
    if (isCustomSourceActive && originalInspectorSource) {
      inspectorManager.source = originalInspectorSource;
      originalInspectorSource = null;
      isCustomSourceActive = false;
    }
  });
}