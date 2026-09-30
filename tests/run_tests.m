import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport
import matlab.unittest.plugins.TestReportPlugin

% Create a test suite
suite = testsuite('.');

% Create a test runner
runner = TestRunner.withTextOutput;

% Add the CodeCoveragePlugin with a CoverageReport
reportFolder = 'reports'; % Folder to save the report
runner.addPlugin(CodeCoveragePlugin.forFolder('../escdf', ...
    'Producing', CoverageReport(fullfile(reportFolder,'MatlabCoverageReport'))));
runner.addPlugin(TestReportPlugin.producingHTML(fullfile(reportFolder,'MatlabExecutionReport')));

% Run the tests
results = runner.run(suite);

% Open the coverage report
web(fullfile(reportFolder, 'MatlabExecutionReport','index.html'));
web(fullfile(reportFolder, 'MatlabCoverageReport','Index.html'));