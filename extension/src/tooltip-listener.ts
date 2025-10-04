import { INotebookTracker } from '@jupyterlab/notebook';

const TOOLTIP_COMM_TARGET = 'tooltip-comm-target';

/**
 * Sets up a listener for Shift+Tab to send a comm message to the kernel.
 *
 * @param notebookTracker The notebook tracker.
 */
export function setupTooltipListener(notebookTracker: INotebookTracker): void {
  document.addEventListener(
    'keydown',
    event => {
      if (event.shiftKey && event.key === 'Tab') {
        const current = notebookTracker.currentWidget;
        if (!current) {
          return;
        }
        const activeCell = current.content.activeCell;
        const isEditorFocused =
          activeCell &&
          activeCell.editor &&
          activeCell.editor.host.contains(document.activeElement);
        if (!isEditorFocused) {
          return;
        }
        const kernel = current.sessionContext.session?.kernel;
        if (kernel) {
          const comm = kernel.createComm(TOOLTIP_COMM_TARGET);
          comm.open({});
          comm.close();
        }
      }
    },
    true // Use capture phase
  );
}