import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin,
  ILabShell
} from '@jupyterlab/application';
import { INotebookTracker } from '@jupyterlab/notebook';
import { IInspector } from '@jupyterlab/inspector';
import { IRenderMimeRegistry } from '@jupyterlab/rendermime';
import { ICompletionProviderManager } from '@jupyterlab/completer';

import { applyCompleterPatch } from './completer';
import { setupInspectorControl } from './inspector';
import { setupCommandsExecutor } from './commands-executor';
import { setupTooltipListener } from './tooltip-listener';

const plugin: JupyterFrontEndPlugin<void> = {
  id: 'jupyterlab-commands-executor:plugin',
  description: 'A multi-purpose JupyterLab kernel interaction extension.',
  autoStart: true,
  requires: [
    INotebookTracker,
    IInspector,
    IRenderMimeRegistry,
    ILabShell,
    ICompletionProviderManager
  ],
  activate: (
    app: JupyterFrontEnd,
    notebookTracker: INotebookTracker,
    inspectorManager,
    rendermime: IRenderMimeRegistry,
    labShell: ILabShell,
    completionManager: ICompletionProviderManager
  ) => {
    // Call each setup function to initialize the functionalities.
    setupInspectorControl(app, inspectorManager, rendermime, labShell);
    setupCommandsExecutor(app, notebookTracker);
    setupTooltipListener(notebookTracker);

    // Apply the completer patch once the application has started.
    app.started.then(() => {
      applyCompleterPatch();
    });
  }
};

export default plugin;