% Run MATLAB interoperability tests against Python-written fixture files.
%
% This script is intended for CI execution from the repository root. It:
% - adds the escdf source folder to the MATLAB path
% - writes a non-interactive ESCDF config file for attribution
% - runs the MATLAB interop tests that consume Python-written fixtures
% - generates JUnit XML and HTML test reports
disp(version);
disp(version('-release'));

addpath(fullfile(pwd, "escdf"));

cfgPath = escdf.escdf_config_path();
disp(['Writing Config File at ', cfgPath])
cfg = struct();
cfg.attribution_name = char('test');
cfg.schema_version = 1;
cfg.updated_utc = char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
escdf.escdf_save_config(cfgPath, cfg);

resultsDir  = fullfile(pwd, "ci_artifacts", "matlab", "interop-test-results");
reportDir   = fullfile(pwd, "ci_artifacts", "matlab", "interop-test-report");

mkdir(resultsDir);
mkdir(reportDir);

suite = testsuite(fullfile(pwd,"tests","interop","read_python_fixtures_test.m"));

runner = matlab.unittest.TestRunner.withTextOutput("Verbosity", 3);

runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
    fullfile(resultsDir, "junit.xml")));

runner.addPlugin(matlab.unittest.plugins.TestReportPlugin.producingHTML( ...
    reportDir, "IncludingPassingDiagnostics", true, "IncludingCommandWindowText", true));

results = runner.run(suite);

save(fullfile(resultsDir,'results.mat'), 'results')

assertSuccess(results);

disp('MATLAB interop read of Python fixtures complete.');