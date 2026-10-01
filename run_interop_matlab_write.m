% Write MATLAB-generated interoperability fixture files.
%
% This script is intended for CI execution from the repository root. It:
% - adds the escdf source folder and interop test folder to the MATLAB path
% - writes a non-interactive ESCDF config file for attribution
% - generates MATLAB-written ESCDF fixture files for cross-language tests
disp(version);
disp(version('-release'));

addpath(genpath(fullfile(pwd, "escdf")));
addpath(fullfile(pwd, "tests", "interop"));

cfgPath = escdf.escdf_config_path();
disp(['Writing Config File at ', cfgPath])
cfg = struct();
cfg.attribution_name = char('test');
cfg.schema_version = 1;
cfg.updated_utc = char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
escdf.escdf_save_config(cfgPath, cfg);

outdir = fullfile(pwd, "ci_artifacts", "interop", "matlab_written");
if ~isfolder(outdir)
    mkdir(outdir);
end

write_matlab_fixtures();

disp('MATLAB interop fixture writing complete.');