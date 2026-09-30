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

        function test_new_escdf_container_starts_in_expected_state(testCase)
            f = escdf();

            testCase.verifyEqual(f.get_lifecycle_state(), 'draft');
            testCase.verifyEqual(f.get_mutability_state(), 'editable');
            testCase.verifyEqual(f.get_backing_state(), 'memory');
            testCase.verifyFalse(f.get_has_pending_changes());

            testCase.verifyClass(f.get_created_date(), 'datetime');
            testCase.verifyNotEmpty(f.get_created_by());
        end

        function test_mutating_container_sets_pending_changes(testCase)
            f = escdf();
            testCase.verifyFalse(f.get_has_pending_changes());

            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_write_to_disk_sets_hdf5_native_and_clears_pending_changes(testCase)
            outfile = fullfile(testCase.temp_folder, 'state_roundtrip.h5');

            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            testCase.verifyTrue(f.get_has_pending_changes());
            testCase.verifyEqual(f.get_backing_state(), 'memory');

            f.write_to_disk(outfile, true);

            testCase.verifyEqual(f.get_backing_state(), 'hdf5_native');
            testCase.verifyFalse(f.get_has_pending_changes());
        end

        function test_loaded_escdf_container_starts_in_expected_state_readonly(testCase)
            outfile = fullfile(testCase.temp_folder, 'loaded_state_readonly.h5');

            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile, true);

            testCase.verifyEqual(loaded.get_backing_state(), 'hdf5_native');
            testCase.verifyEqual(loaded.get_lifecycle_state(), 'draft');
            testCase.verifyEqual(loaded.get_mutability_state(), 'read_only');
            testCase.verifyFalse(loaded.get_has_pending_changes());
        end

        function test_loaded_escdf_container_starts_in_expected_state_editable(testCase)
            outfile = fullfile(testCase.temp_folder, 'loaded_state_editable.h5');

            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile, false);

            testCase.verifyEqual(loaded.get_backing_state(), 'hdf5_native');
            testCase.verifyEqual(loaded.get_lifecycle_state(), 'draft');
            testCase.verifyEqual(loaded.get_mutability_state(), 'editable');
            testCase.verifyFalse(loaded.get_has_pending_changes());
        end

        function test_set_created_properties_marks_pending_changes(testCase)
            f = escdf();
            testCase.verifyFalse(f.get_has_pending_changes());

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.set_created_properties('someone_else', when);

            testCase.verifyEqual(f.get_created_by(), 'someone_else');
            testCase.verifyEqual(f.get_created_date(), when);
            testCase.verifyTrue(f.get_has_pending_changes());
        end

                function test_add_metadata_clones_in_memory_dataset_wrapper(testCase)
        % Verify that adding in-memory metadata clones the dataset wrapper
        % and preserves memory-backed property state.
            source_md = escdf_ops_test.make_minimal_metadata('meta1');
            source_md.test_name = {'Original Test Name'};

            f = escdf();
            f.add_metadata(source_md);

            attached_md = f.get_metadata('meta1');

            % The attached dataset should be a different wrapper object.
            testCase.verifyFalse(attached_md == source_md);

            % In-memory properties should remain memory-backed in the clone.
            testCase.verifyEqual(attached_md.test_name.get_backing_state(), 'memory');
            testCase.verifyEqual(attached_md.program.get_backing_state(), 'memory');
            testCase.verifyEqual(attached_md.hardware_list.get_backing_state(), 'memory');
            testCase.verifyEqual(attached_md.point_of_contact.get_backing_state(), 'memory');

            % Values should match.
            testCase.verifyEqual(attached_md.test_name(:), {'Original Test Name'});
            testCase.verifyEqual(attached_md.program(:), {'program abc'});
        end

        function test_add_metadata_clones_hdf5_native_properties_as_external(testCase)
        % Verify that adding HDF5-native metadata into a new container
        % clones the dataset wrapper and marks properties external-backed.
            source_file_path = fullfile(testCase.temp_folder, 'source_metadata.h5');

            source_file = escdf();
            source_md = escdf_ops_test.make_minimal_metadata('meta1');
            source_file.add_metadata(source_md);
            source_file.write_to_disk(source_file_path, true);

            loaded = escdf.load(source_file_path, true);
            loaded_md = loaded.get_metadata('meta1');

            % Loaded source should be native HDF5-backed.
            testCase.verifyEqual(loaded_md.test_name.get_backing_state(), 'hdf5_native');

            target = escdf();
            target.add_metadata(loaded_md);

            attached_md = target.get_metadata('meta1');

            % Copied attached properties should now be externally backed.
            testCase.verifyEqual(attached_md.test_name.get_backing_state(), 'hdf5_external');
            testCase.verifyEqual(attached_md.program.get_backing_state(), 'hdf5_external');
            testCase.verifyEqual(attached_md.hardware_list.get_backing_state(), 'hdf5_external');
            testCase.verifyEqual(attached_md.point_of_contact.get_backing_state(), 'hdf5_external');

            % Values should still read correctly.
            testCase.verifyEqual(attached_md.test_name(:), {'test program name'});
            testCase.verifyEqual(attached_md.program(:), {'program abc'});
        end

        function test_mutating_external_backed_attached_metadata_materializes_clone_only(testCase)
        % Verify that mutating an external-backed attached clone
        % materializes it to memory and leaves the original source
        % unchanged.
            source_file_path = fullfile(testCase.temp_folder, 'source_metadata_for_mutation.h5');

            source_file = escdf();
            source_md = escdf_ops_test.make_minimal_metadata('meta1');
            source_file.add_metadata(source_md);
            source_file.write_to_disk(source_file_path, true);

            loaded = escdf.load(source_file_path, true);
            loaded_md = loaded.get_metadata('meta1');

            target = escdf();
            target.add_metadata(loaded_md);
            attached_md = target.get_metadata('meta1');

            % Initially external-backed in the attached clone.
            testCase.verifyEqual(attached_md.test_name.get_backing_state(), 'hdf5_external');

            % Mutating should materialize to memory for the clone.
            attached_md.test_name = {'Modified In Clone'};

            testCase.verifyEqual(attached_md.test_name.get_backing_state(), 'memory');
            testCase.verifyEqual(attached_md.test_name(:), {'Modified In Clone'});

            % Original loaded dataset should remain unchanged and still native-backed.
            testCase.verifyEqual(loaded_md.test_name.get_backing_state(), 'hdf5_native');
            testCase.verifyEqual(loaded_md.test_name(:), {'test program name'});
        end

        function test_add_data_to_activity_clones_dataset_wrapper(testCase)
        % Verify that adding in-memory activity data clones the dataset
        % wrapper and preserves memory-backed property state.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            source_data = escdf_ops_test.make_minimal_data('data1');
            source_data.value = 9.81;
            source_data.unit = {'m/s^2'};
            testCase.verifyTrue(source_data.validate());

            f.add_data_to_activity('act1', source_data);

            attached_data = f.get_activity_data('act1', 'data1');

            % Dataset wrapper should be cloned rather than reused directly.
            testCase.verifyFalse(attached_data == source_data);

            % In-memory properties remain memory-backed.
            testCase.verifyEqual(attached_data.value.get_backing_state(), 'memory');
            testCase.verifyEqual(attached_data.unit.get_backing_state(), 'memory');

            testCase.verifyEqual(attached_data.value(:), 9.81);
            testCase.verifyEqual(attached_data.unit(:), {'m/s^2'});
        end

        function test_add_hdf5_native_data_to_activity_creates_external_backed_clone(testCase)
        % Verify that adding HDF5-native activity data into a new
        % container/activity creates an external-backed clone.
            source_file_path = fullfile(testCase.temp_folder, 'source_activity_data.h5');
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');

            source_file = escdf();
            source_file.add_activity('act1', 'Activity one', when);

            source_data = escdf_ops_test.make_minimal_data('data1');
            source_data.value = 9.81;
            source_data.unit = {'m/s^2'};
            testCase.verifyTrue(source_data.validate());

            source_file.add_data_to_activity('act1', source_data);
            source_file.write_to_disk(source_file_path, true);

            loaded = escdf.load(source_file_path, true);
            loaded_data = loaded.get_activity_data('act1', 'data1');

            % Loaded source should be native HDF5-backed.
            testCase.verifyEqual(loaded_data.value.get_backing_state(), 'hdf5_native');

            target = escdf();
            target.add_activity('act2', 'Activity two', when);
            target.add_data_to_activity('act2', loaded_data);

            attached_data = target.get_activity_data('act2', 'data1');

            % Dataset wrapper should be cloned.
            testCase.verifyFalse(attached_data == loaded_data);

            % Copied attached properties should now be externally backed.
            testCase.verifyEqual(attached_data.value.get_backing_state(), 'hdf5_external');
            testCase.verifyEqual(attached_data.unit.get_backing_state(), 'hdf5_external');

            % Values should still read correctly.
            testCase.verifyEqual(attached_data.value(:), 9.81);
            testCase.verifyEqual(attached_data.unit(:), {'m/s^2'});
        end

        
    end
end