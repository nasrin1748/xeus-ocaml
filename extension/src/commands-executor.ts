// src/commands-executor.ts

import { JupyterFrontEnd } from '@jupyterlab/application';
import { INotebookTracker, NotebookPanel } from '@jupyterlab/notebook';
import { IKernelConnection } from '@jupyterlab/services/lib/kernel/kernel';

const COMM_TARGET_NAME = 'jupyterlab-commands-executor';

/**
 * Sets up the comm target for executing frontend commands from the kernel.
 *
 * @param app The JupyterFrontEnd application instance.
 * @param notebookTracker The notebook tracker.
 */
export function setupCommandsExecutor(
  app: JupyterFrontEnd,
  notebookTracker: INotebookTracker
): void {
  const registeredKernels = new Set<string>();

  const registerCommTarget = (kernel: IKernelConnection): void => {
    if (registeredKernels.has(kernel.id)) {
      return;
    }
    kernel.registerCommTarget(COMM_TARGET_NAME, (comm, openMsg) => {
      const data = openMsg.content.data as { command: string; args?: any };
      const { command, args } = data;
      if (!command) {
        comm.close();
        return;
      }
      app.commands.execute(command, args || {}).finally(() => {
        comm.close();
      });
    });
    registeredKernels.add(kernel.id);
    kernel.disposed.connect(() => {
      registeredKernels.delete(kernel.id);
    });
  };

  const connectToNotebook = (panel: NotebookPanel) => {
    panel.sessionContext.ready.then(() => {
      const kernel = panel.sessionContext.session?.kernel;
      if (kernel) {
        registerCommTarget(kernel);
      }
    });
    panel.sessionContext.kernelChanged.connect((_, args) => {
      if (args.newValue) {
        registerCommTarget(args.newValue);
      }
    });
  };

  notebookTracker.widgetAdded.connect((_, panel) => {
    connectToNotebook(panel);
  });
}