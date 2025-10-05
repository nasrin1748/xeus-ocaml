
const { merlinSync, toplevelAsync } = global.xocaml_api;

const callToplevelAsync = (command, payload) => {
  const request = JSON.stringify(payload === undefined ? [command] : [command, payload]);
  return new Promise((resolve) => {
    toplevelAsync(request, (result) => {
      resolve(JSON.parse(result));
    });
  });
};

const callMerlinSync = (command, payload) => {
  const request = JSON.stringify([command, payload]);
  const result = merlinSync(request);
  return JSON.parse(result);
};

// Use module.exports instead of 'export'
module.exports = {
  callToplevelAsync,
  callMerlinSync,
};