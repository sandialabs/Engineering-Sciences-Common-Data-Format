% Run the MATLAB unit test suite for ESCDF.
%
% This script is intended for CI execution from the repository root. It:
% - adds the escdf source folder to the MATLAB path
% - writes a non-interactive ESCDF config file for attribution
% - runs the MATLAB unit tests excluding interop tests
% - generates JUnit XML, HTML test reports, and HTML code coverage output
% - writes statement coverage percentage to a text artifact

disp(version);
disp(version('-release'));

addpath(genpath(fullfile(pwd, "escdf")));

cfgPath = escdf.escdf_config_path();
disp(['Writing Config File at ', cfgPath])
cfg = struct();
cfg.attribution_name = char('test');
cfg.schema_version = 1;
cfg.updated_utc = char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
escdf.escdf_save_config(cfgPath, cfg);

resultsDir  = fullfile(pwd, "ci_artifacts", "matlab", "test-results");
reportDir   = fullfile(pwd, "ci_artifacts", "matlab", "test-report");
covDir      = fullfile(pwd, "ci_artifacts", "matlab", "coverage");
covHtmlDir  = fullfile(covDir, "html");

mkdir(resultsDir); mkdir(reportDir); mkdir(covDir); mkdir(covHtmlDir);

% Discover tests
suite = testsuite(fullfile(pwd,"tests"), "IncludeSubfolders", true);

% Exclude interop tests from the basic MATLAB suite.
% Interoperability tests are executed in separate CI jobs because they depend
% on cross-language fixture artifacts. Exclude them from the basic MATLAB suite.
interop_test_classes = [
    "read_python_fixtures_test"
];

keep_mask = true(size(suite));
for i = 1:numel(suite)
    test_name = string(suite(i).Name);
    for j = 1:numel(interop_test_classes)
        if contains(test_name, interop_test_classes(j))
            keep_mask(i) = false;
            break;
        end
    end
end

suite = suite(keep_mask);

% Build runner + plugins
runner = matlab.unittest.TestRunner.withTextOutput("Verbosity", 3);

% JUnit XML (nice for GitLab test report UI)
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
    fullfile(resultsDir, "junit.xml")));

% HTML test report
runner.addPlugin(matlab.unittest.plugins.TestReportPlugin.producingHTML( ...
    reportDir, "IncludingPassingDiagnostics", true, "IncludingCommandWindowText", true));

% Coverage: pick what to measure.
% Common choice: cover code under escdf/ (adjust to your layout)
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport

covReport = CoverageReport(covHtmlDir);
runner.addPlugin(CodeCoveragePlugin.forFolder(fullfile(pwd,"escdf"), ...
    "IncludingSubfolders", true, "Producing", covReport));

% Run
results = runner.run(suite);

save(fullfile(resultsDir,'results.mat'), 'results')

% Fail CI if any test failed
assertSuccess(results);

jsFile = fullfile(covHtmlDir, 'release','coverageData','OverallCoverageData.js');

txt = fileread(jsFile);

% Strip "var overallCoverageData = " and trailing semicolon
txt = regexprep(txt, '^\s*var\s+overallCoverageData\s*=\s*', '');
txt = regexprep(txt, ';\s*$', '');

data = jsondecode(txt);

stmtPct = data.OverallCoverageMetrics.Statement.PercentCoverage;
fprintf("Statement coverage: %.2f%%\n", stmtPct);

% simplest: plain text
coverageTxt = fullfile(covDir, "statement_coverage_percent.txt");
fid = fopen(coverageTxt, "w");
assert(fid > 0, "Could not open %s for writing.", coverageTxt);
fprintf(fid, "%.0f\n", stmtPct);
fclose(fid);