classdef escdf_ops_test < matlab.unittest.TestCase
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
        function ds = make_minimal_metadata(name)
            ds = escdf_dataset(name, 'global_test_attributes', 'Global test metadata');
            ds.test_name = {'test program name'};
            ds.program = {'program abc'};
            ds.hardware_list = {'hardware_a'; 'hardware_b'};
            ds.point_of_contact = {'person_1'; 'person_2'};
        end

        function ds = make_minimal_data(name)
            ds = escdf_dataset(name, 'scalar', 'Scalar result');
            ds.value = 1.25;
            ds.unit = {'g'};
        end
    end

    methods (Test)
        function test_empty_escdf_initialization(testCase)
            f = escdf();
            testCase.verifyEmpty(f.activities);
            testCase.verifyEmpty(f.metadata);

            s = evalc('disp(f)');
            testCase.verifyNotEmpty(s);
        end

        function test_add_metadata(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            testCase.verifyTrue(md.validate());

            f.add_metadata(md);

            metadata = f.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'meta1');
        end

        function test_add_duplicate_metadata_raises(testCase)
            f = escdf();
            f.add_metadata(escdf_ops_test.make_minimal_metadata('meta1'));

            didError = false;
            try
                f.add_metadata(escdf_ops_test.make_minimal_metadata('meta1'));
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_add_activity(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');

            f.add_activity('act1', 'Activity one', when);

            activities = f.get_activity();
            testCase.verifyEqual(numel(activities), 1);
            testCase.verifyEqual(activities(1).get_name(), 'act1');
            testCase.verifyEqual(activities(1).get_descriptive_name(), 'Activity one');
            testCase.verifyEqual(activities(1).get_date(), when);
        end

        function test_add_duplicate_activity_raises(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');

            f.add_activity('act1', 'Activity one', when);

            didError = false;
            try
                f.add_activity('act1', 'Activity duplicate', when);
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_add_activity_with_missing_metadata_link_raises(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');

            didError = false;
            try
                f.add_activity('act1', 'Activity one', when, [], {'missing_meta'});
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_link_and_unlink_metadata(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            f.link_activity_to_metadata('act1', 'meta1');
            activity = f.get_activity('act1');
            testCase.verifyEqual(activity.get_metadata_links(), {'meta1'});

            f.unlink_activity_from_metadata('act1', 'meta1');
            activity = f.get_activity('act1');
            testCase.verifyEmpty(activity.get_metadata_links());
        end

        function test_link_missing_metadata_raises(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            didError = false;
            try
                f.link_activity_to_metadata('act1', 'missing_meta');
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_add_and_remove_data_from_activity(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            testCase.verifyTrue(data.validate());

            f.add_data_to_activity('act1', data);

            retrieved = f.get_activity_data('act1', 'data1');
            testCase.verifyEqual(retrieved.get_name(), 'data1');

            activity = f.get_activity('act1');
            testCase.verifyEqual(activity.get_data_names(), {'data1'});

            f.remove_data_from_activity('act1', 'data1');
            activity = f.get_activity('act1');
            testCase.verifyEmpty(activity.get_data_names());
        end

        function test_add_non_activity_result_to_activity_raises(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            md = escdf_ops_test.make_minimal_metadata('meta1');

            didError = false;
            try
                f.add_data_to_activity('act1', md);
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_get_activity_metadata(testCase)
            f = escdf();

            md1 = escdf_ops_test.make_minimal_metadata('meta1');
            md2 = escdf_ops_test.make_minimal_metadata('meta2');
            f.add_metadata(md1);
            f.add_metadata(md2);

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            f.link_activity_to_metadata('act1', 'meta1');
            f.link_activity_to_metadata('act1', 'meta2');

            linked = f.get_activity_metadata('act1');
            linked_names = arrayfun(@(x) x.get_name(), linked, 'UniformOutput', false);
            testCase.verifyEqual(linked_names, {'meta1','meta2'});
        end

        function test_simple_file_roundtrip(testCase)
            outfile = fullfile(testCase.temp_folder, 'roundtrip.h5');

            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            data = escdf_ops_test.make_minimal_data('data1');
            when = datetime(2024,1,2,3,4,5.123456,'TimeZone','UTC');

            f.set_created_properties('unit_test_user', datetime(2024,1,1,12,0,0,'TimeZone','UTC'));
            f.add_metadata(md);
            f.add_activity('act1', 'Activity one', when);
            f.link_activity_to_metadata('act1', 'meta1');
            f.add_data_to_activity('act1', data);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);

            metadata = loaded.get_metadata();
            activities = loaded.get_activity();

            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(numel(activities), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'meta1');
            testCase.verifyEqual(activities(1).get_name(), 'act1');

            activity = loaded.get_activity('act1');
            testCase.verifyEqual(activity.get_metadata_links(), {'meta1'});
            testCase.verifyEqual(activity.get_data_names(), {'data1'});
            testCase.verifyLessThan(seconds(abs(activity.get_date() - when)), 1e-4);
        end
    end
end