        document.addEventListener('DOMContentLoaded', () => {
            // === 1. Get references to ALL elements by ID ===
            const codeInput = document.getElementById('code-input');
            const outputElement = document.getElementById('json-output');
            const statusElement = document.getElementById('status');
            
            const setupBtn = document.getElementById('btn-setup');
            const evalBtn = document.getElementById('btn-eval');
            const completeBtn = document.getElementById('btn-complete');
            const typeBtn = document.getElementById('btn-type');
            const docBtn = document.getElementById('btn-doc');
            const errorsBtn = document.getElementById('btn-errors');

            // Group all buttons that should be enabled after setup
            const allActionButtons = [evalBtn, completeBtn, typeBtn, docBtn, errorsBtn];
            const originalSetupBtnContent = setupBtn.innerHTML;
            const spinnerIcon = `<svg class="spinner" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0011.664 0l3.181-3.183m-4.991-2.693L7.5 7.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>`;

            if (!window.xocaml?.processMerlinAction || !window.xocaml?.processToplevelAction) {
                statusElement.textContent = "Fatal Error: xocaml.js did not export required functions.";
                setupBtn.disabled = true;
                return;
            }
            const { processMerlinAction, processToplevelAction } = window.xocaml;

            // === 2. Define Helper Functions ===

            // Generic helper to display a JSON object
            function displayJsonResponse(response) {
                outputElement.innerHTML = '';
                const pre = document.createElement('pre');
                pre.textContent = JSON.stringify(response, null, 2);
                outputElement.appendChild(pre);
            }

            // Specific helper for the special output format of the 'Eval' command
            function displayEvalResponse(response) {
                outputElement.innerHTML = '';
                 if (response.class === 'return' && Array.isArray(response.value)) {
                    response.value.forEach(([tag, content]) => {
                        const pre = document.createElement('pre');
                        pre.className = 'caml_' + tag.toLowerCase();
                        pre.textContent = content;
                        outputElement.appendChild(pre);
                    });
                } else {
                    // Fallback to JSON display if the format is unexpected
                    displayJsonResponse(response);
                }
            }
            
            // Wrapper for ASYNC OCaml calls
            function callToplevelAsync(command, payload) {
                const request = JSON.stringify(payload === undefined ? [command] : [command, payload]);
                console.log("Sending Async:", request);
                return new Promise((resolve) => {
                    processToplevelAction(request, (result) => {
                        console.log("Received Async:", result);
                        resolve(JSON.parse(result));
                    });
                });
            }

            // Wrapper for SYNC OCaml calls
            function callMerlinSync(command, payload) {
                const request = JSON.stringify([command, payload]);
                console.log("Sending Sync:", request);
                const result = processMerlinAction(request);
                console.log("Received Sync:", result);
                return JSON.parse(result);
            }

            // === 3. Setup Logic ===

           
            async function handleSetup() {
                const originalContent = setupBtn.innerHTML;
                setupBtn.innerHTML = `${spinnerIcon} <span>Initializing...</span>`;
                setupBtn.disabled = true;
                statusElement.textContent = "Initializing environment...";

                const payload = {
                    dsc_url: "./stdlib"
                };

                const response = await callToplevelAsync('Setup', payload);
                displayJsonResponse(response);

                if (response?.class === 'return') {
                    statusElement.textContent = "✅ Environment Ready!";
                    allActionButtons.forEach(btn => btn.disabled = false);
                    setupBtn.innerHTML = originalSetupBtnContent;
                } else {
                    statusElement.textContent = `❌ Initialization Failed.`;
                    setupBtn.innerHTML = originalSetupBtnContent;
                    setupBtn.disabled = false;
                }
            }
            
            // === 4. Attach ALL Event Listeners ===

            
const merlinActions = {
    'btn-complete': 'Complete_prefix',
    'btn-type': 'Type_enclosing',
    'btn-doc': 'Document',
};

for (const [btnId, action] of Object.entries(merlinActions)) {
    document.getElementById(btnId).addEventListener('click', () => {
        const response = callMerlinSync(action, {
            source: codeInput.value,
            position: ["Offset", codeInput.selectionStart]
        });
        displayJsonResponse(response);
    });
}

// Handle buttons with different payloads separately
errorsBtn.addEventListener('click', () => {
    const response = callMerlinSync('All_errors', { source: codeInput.value });
    displayJsonResponse(response);
});

evalBtn.addEventListener('click', async () => {
    const response = await callToplevelAsync('Eval', { source: codeInput.value });
    displayEvalResponse(response);
});

setupBtn.addEventListener('click', handleSetup);
        });
