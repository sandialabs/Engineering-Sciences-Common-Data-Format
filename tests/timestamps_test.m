classdef timestamps_test < matlab.unittest.TestCase

    properties
        temp_folder
        original_path
        source_folder
    end

    methods (TestMethodSetup)
        function setupEnvironment(testCase)
            current_file_folder = fileparts(mfilename('fullpath'));
            testCase.source_folder = fullfile(current_file_folder, '..', 'escdf');
            testCase.temp_folder = tempname;
            testCase.original_path = addpath(testCase.source_folder);
            mkdir(testCase.temp_folder);
        end
    end

    methods (TestMethodTeardown)
        function teardownEnvironment(testCase)
            if isfolder(testCase.temp_folder)
                rmdir(testCase.temp_folder, 's');
            end
            path(testCase.original_path);
        end
    end

    methods (Static)
        function verifyDatetimesNearlyEqual(testCase, actual, expected, tol_seconds)
            if nargin < 4
                tol_seconds = 1e-6;
            end
            testCase.verifyLessThan(seconds(abs(actual - expected)), tol_seconds);
        end
    end

    methods (Test)

        function test_datetime_to_iso_utc_from_aware_utc(testCase)
            value = datetime(2024,1,2,3,4,5.123456, 'TimeZone','UTC');
            out = escdf.datetime_to_iso_utc(value);
            testCase.verifyEqual(out, '2024-01-02T03:04:05.123456Z');
        end

        function test_datetime_to_iso_utc_from_offset_timezone(testCase)
            value = datetime(2024,1,2,5,4,5.123456, 'TimeZone','Europe/Berlin');
            % This test assumes wintertime offset of +1 for Jan 2 in Berlin
            out = escdf.datetime_to_iso_utc(value);
            testCase.verifyEqual(out, '2024-01-02T04:04:05.123456Z');
        end

        function test_datetime_to_iso_utc_warns_on_naive_datetime(testCase)
            value = datetime(2024,1,2,3,4,5.123456);
            testCase.verifyWarning(@() escdf.datetime_to_iso_utc(value), 'ESCDF:NaiveDatetime');
            out = escdf.datetime_to_iso_utc(value);
            testCase.verifyEqual(out, '2024-01-02T03:04:05.123456Z');
        end

        function test_datetime_from_iso_utc_canonical(testCase)
            value = escdf.datetime_from_iso_utc('2024-01-02T03:04:05.123456Z');
            expected = datetime(2024,1,2,3,4,5.123456, 'TimeZone','UTC');
            timestamps_test.verifyDatetimesNearlyEqual(testCase, value, expected);
            testCase.verifyEqual(value.TimeZone, 'UTC');
        end

        function test_datetime_from_iso_utc_no_fraction(testCase)
            value = escdf.datetime_from_iso_utc('2024-01-02T03:04:05Z');
            expected = datetime(2024,1,2,3,4,5, 'TimeZone','UTC');
            timestamps_test.verifyDatetimesNearlyEqual(testCase, value, expected);
            testCase.verifyEqual(value.TimeZone, 'UTC');
        end

        function test_datetime_from_iso_utc_warns_on_naive_string(testCase)
            testCase.verifyWarning( ...
                @() escdf.datetime_from_iso_utc('2024-01-02T03:04:05.123456'), ...
                'ESCDF:NaiveDatetimeString');

            value = escdf.datetime_from_iso_utc('2024-01-02T03:04:05.123456');
            expected = datetime(2024,1,2,3,4,5.123456, 'TimeZone','UTC');
            timestamps_test.verifyDatetimesNearlyEqual(testCase, value, expected);
        end

        function test_datetime_from_iso_utc_rejects_invalid(testCase)
            didError = false;
            try
                escdf.datetime_from_iso_utc('not-a-datetime');
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_file_roundtrip_preserves_created_date(testCase)
            outfile = fullfile(testCase.temp_folder, 'created_date_roundtrip.h5');

            f = escdf();
            created_time = datetime(2025,2,3,4,5,6.789125, 'TimeZone','UTC');
            f.set_created_properties('unit_test_user', created_time);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);

            metadata = loaded.get_metadata();
            activities = loaded.get_activity(); %#ok<NASGU>

            s = evalc('disp(loaded)');
            testCase.verifyNotEmpty(s);

            % created_date is private, so verify indirectly from file
            created_date_raw = h5readatt(outfile, '/', 'created_date');
            testCase.verifyEqual(created_date_raw, '2025-02-03T04:05:06.789125Z');
        end

        function test_activity_roundtrip_preserves_activity_date(testCase)
            outfile = fullfile(testCase.temp_folder, 'activity_date_roundtrip.h5');

            f = escdf();
            activity_time = datetime(2025,7,8,9,10,11.456789, 'TimeZone','UTC');

            f.add_activity('act1', 'Activity', activity_time);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);
            activity = loaded.get_activity('act1');

            timestamps_test.verifyDatetimesNearlyEqual(testCase, activity.get_date(), activity_time);

            activity_date_raw = h5readatt(outfile, '/activities/act1', 'activity_date');
            testCase.verifyEqual(activity_date_raw, '2025-07-08T09:10:11.456789Z');
        end
    end
end