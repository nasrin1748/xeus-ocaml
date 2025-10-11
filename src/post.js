Module['FS'] = FS;
Module['PATH'] = PATH;
Module['LDSO'] = LDSO;
Module['getDylinkMetadata'] = getDylinkMetadata;
Module['loadDynamicLibrary'] = loadDynamicLibrary;

Module.FS = FS;

if (!('wasmTable' in Module)) {
    Module['wasmTable'] = wasmTable
}


// // Helper functions for file operations that OCaml can call
// Module.fs_operations = {
//     writeFile: function(path, data, options) {
//         try {
//             FS.writeFile(path, data, options);
//             return { success: true };
//         } catch (e) {
//             return { success: false, error: e.toString() };
//         }
//     },
    
//     readFile: function(path, options) {
//         try {
//             const data = FS.readFile(path, options);
//             return { success: true, data: data };
//         } catch (e) {
//             return { success: false, error: e.toString() };
//         }
//     },
    
//     mkdir: function(path, mode) {
//         try {
//             FS.mkdir(path, mode);
//             return { success: true };
//         } catch (e) {
//             return { success: false, error: e.toString() };
//         }
//     },
    
//     readdir: function(path) {
//         try {
//             const entries = FS.readdir(path);
//             return { success: true, entries: entries };
//         } catch (e) {
//             return { success: false, error: e.toString() };
//         }
//     },
    
//     unlink: function(path) {
//         try {
//             FS.unlink(path);
//             return { success: true };
//         } catch (e) {
//             return { success: false, error: e.toString() };
//         }
//     },
    
//     stat: function(path) {
//         try {
//             const stat = FS.stat(path);
//             return { 
//                 success: true, 
//                 stat: {
//                     isDirectory: FS.isDir(stat.mode),
//                     isFile: FS.isFile(stat.mode),
//                     size: stat.size,
//                     mtime: stat.mtime
//                 }
//             };
//         } catch (e) {
//             return { success: false, error: e.toString() };
//         }
//     }
// };