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
            testCase.verifyEmpty(f.get_hdf5_location());
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
            testCase.verifyEmpty(f.get_hdf5_location());

            f.write_to_disk(outfile, true);

            testCase.verifyNotEmpty(f.get_hdf5_location());
            testCase.verifyFalse(f.get_has_pending_changes());
        end

        function test_loaded_escdf_container_starts_in_expected_state_readonly(testCase)
            outfile = fullfile(testCase.temp_folder, 'loaded_state_readonly.h5');

            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile, true);

            testCase.verifyNotEmpty(loaded.get_hdf5_location());
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

            testCase.verifyNotEmpty(loaded.get_hdf5_location());
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
            testCase.verifyEmpty(attached_md.test_name.get_hdf5_location());
            testCase.verifyEmpty(attached_md.program.get_hdf5_location());
            testCase.verifyEmpty(attached_md.hardware_list.get_hdf5_location());
            testCase.verifyEmpty(attached_md.point_of_contact.get_hdf5_location());

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
            testCase.verifyNotEmpty(loaded_md.test_name.get_hdf5_location());

            target = escdf();
            target.add_metadata(loaded_md);

            attached_md = target.get_metadata('meta1');

            % New wrapper object
            testCase.verifyFalse(attached_md == loaded_md)

            % Copied attached properties should now be externally backed.
            testCase.verifyTrue(attached_md.test_name.same_backing_location_as(loaded_md.test_name));
            testCase.verifyTrue(attached_md.program.same_backing_location_as(loaded_md.program));
            testCase.verifyTrue(attached_md.hardware_list.same_backing_location_as(loaded_md.hardware_list));
            testCase.verifyTrue(attached_md.point_of_contact.same_backing_location_as(loaded_md.point_of_contact));

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
            testCase.verifyTrue(attached_md.test_name.same_backing_location_as(loaded_md.test_name))

            % Mutating should materialize to memory for the clone.
            attached_md.test_name = {'Modified In Clone'};

            testCase.verifyEmpty(attached_md.test_name.get_hdf5_location());
            testCase.verifyEqual(attached_md.test_name(:), {'Modified In Clone'});

            % Original loaded dataset should remain unchanged and still native-backed.
            testCase.verifyNotEmpty(loaded_md.test_name.get_hdf5_location());
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
            testCase.verifyEmpty(attached_data.value.get_hdf5_location());
            testCase.verifyEmpty(attached_data.unit.get_hdf5_location());

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
            testCase.verifyNotEmpty(loaded_data.value.get_hdf5_location());

            target = escdf();
            target.add_activity('act2', 'Activity two', when);
            target.add_data_to_activity('act2', loaded_data);

            attached_data = target.get_activity_data('act2', 'data1');

            % Dataset wrapper should be cloned.
            testCase.verifyFalse(attached_data == loaded_data);

            % Copied attached properties should now be externally backed.
            testCase.verifyTrue(attached_data.value.same_backing_location_as(loaded_data.value));
            testCase.verifyTrue(attached_data.unit.same_backing_location_as(loaded_data.unit));

            % Values should still read correctly.
            testCase.verifyEqual(attached_data.value(:), 9.81);
            testCase.verifyEqual(attached_data.unit(:), {'m/s^2'});
        end

        function test_new_activity_starts_in_expected_state(testCase)
        % Verify that a newly constructed activity starts memory-backed
        % with no pending changes.
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            testCase.verifyEmpty(activity.get_hdf5_location());
            testCase.verifyFalse(activity.get_has_pending_changes());
        end

        function test_activity_link_to_metadata_sets_pending_changes(testCase)
        % Verify that linking metadata marks the activity as having pending changes.
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            testCase.verifyFalse(activity.get_has_pending_changes());
            activity.link_to_metadata('meta1');
            testCase.verifyTrue(activity.get_has_pending_changes());
        end

        function test_activity_add_data_sets_pending_changes(testCase)
        % Verify that adding data marks the activity as having pending changes.
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');

            testCase.verifyFalse(activity.get_has_pending_changes());
            activity.add_data(data);
            testCase.verifyTrue(activity.get_has_pending_changes());
        end

        function test_loaded_activity_starts_hdf5_native_with_no_pending_changes(testCase)
        % Verify that an activity loaded from disk starts HDF5-native and
        % has no pending changes.
            outfile = fullfile(testCase.temp_folder, 'loaded_activity_state.h5');

            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);
            loaded_activity = loaded.get_activity('act1');

            testCase.verifyNotEmpty(loaded_activity.get_hdf5_location());
            testCase.verifyFalse(loaded_activity.get_has_pending_changes());
        end

        function test_activity_write_to_disk_sets_hdf5_native_and_clears_pending_changes(testCase)
        % Verify that writing an activity to disk sets it HDF5-native and
        % clears pending changes.
            outfile = fullfile(testCase.temp_folder, 'activity_write_state.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
            activity_group = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            activity.add_data(data);

            testCase.verifyEmpty(activity.get_hdf5_location());
            testCase.verifyTrue(activity.get_has_pending_changes());

            activity.write_to_disk(activity_group);

            testCase.verifyNotEmpty(activity.get_hdf5_location());
            testCase.verifyFalse(activity.get_has_pending_changes());

            H5G.close(activity_group);
            H5F.close(file_id);
        end

        function test_activity_remove_data_returns_removed_dataset(testCase)
        % Verify that removing data from an activity returns the removed
        % dataset object and marks the activity as having pending changes.
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');

            activity.add_data(data);
            testCase.verifyTrue(any(strcmp(activity.get_data_names(), 'data1')));
            testCase.verifyTrue(activity.get_has_pending_changes());

            % Reset to isolate the effect of the remove call.
            activity.set_has_pending_changes(false);

            removed = activity.remove_data('data1');

            testCase.verifyEqual(removed.get_name(), 'data1');
            testCase.verifyFalse(any(strcmp(activity.get_data_names(), 'data1')));
            testCase.verifyTrue(activity.get_has_pending_changes());
        end

        function test_activity_remove_data_raises_for_missing_dataset(testCase)
        % Verify that removing a missing dataset raises an error.
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            did_error = false;
            try
                activity.remove_data('missing_data');
            catch
                did_error = true;
            end

            testCase.verifyTrue(did_error);
        end

        function test_container_remove_data_from_activity_returns_removed_dataset(testCase)
        % Verify that removing data from an activity through the container
        % returns the removed dataset and marks both activity and container
        % as having pending changes.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);

            testCase.verifyTrue(any(strcmp(f.get_activity('act1').get_data_names(), 'data1')));

            % Reset to isolate the effect of the remove call.
            f.set_has_pending_changes(false);
            f.get_activity('act1').set_has_pending_changes(false);

            removed = f.remove_data_from_activity('act1', 'data1');

            testCase.verifyEqual(removed.get_name(), 'data1');
            testCase.verifyFalse(any(strcmp(f.get_activity('act1').get_data_names(), 'data1')));
            testCase.verifyTrue(f.get_activity('act1').get_has_pending_changes());
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_removed_dataset_can_be_moved_to_another_activity(testCase)
        % Verify that a removed dataset object can be moved into another
        % activity.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            f.add_activity('act2', 'Activity two', when);

            data = escdf_ops_test.make_minimal_data('data1');
            data.value = 9.81;
            data.unit = {'m/s^2'};
            testCase.verifyTrue(data.validate());

            f.add_data_to_activity('act1', data);
            removed = f.remove_data_from_activity('act1', 'data1');

            testCase.verifyFalse(any(strcmp(f.get_activity('act1').get_data_names(), 'data1')));

            f.add_data_to_activity('act2', removed);

            testCase.verifyTrue(any(strcmp(f.get_activity('act2').get_data_names(), 'data1')));
            moved = f.get_activity_data('act2', 'data1');
            testCase.verifyEqual(moved.value(:), 9.81);
            testCase.verifyEqual(moved.unit(:), {'m/s^2'});
        end

        function test_remove_metadata_returns_removed_object(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            removed = f.remove_metadata('meta1');

            testCase.verifyEqual(removed.get_name(), 'meta1');
            testCase.verifyFalse(any(strcmp(f.get_metadata_names(), 'meta1')));
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_remove_metadata_fails_if_still_linked_without_unlink(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md, 'act1');

            did_error = false;
            try
                f.remove_metadata('meta1');
            catch
                did_error = true;
            end
            testCase.verifyTrue(did_error);
        end

        function test_remove_metadata_with_unlink_removes_links(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md, 'act1');

            removed = f.remove_metadata('meta1', true);

            testCase.verifyEqual(removed.get_name(), 'meta1');
            testCase.verifyFalse(any(strcmp(f.get_metadata_names(), 'meta1')));
            testCase.verifyFalse(any(strcmp(f.get_activity('act1').get_metadata_links(), 'meta1')));
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_remove_activity_returns_removed_object(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            removed = f.remove_activity('act1');

            testCase.verifyEqual(removed.get_name(), 'act1');
            testCase.verifyFalse(any(strcmp(f.get_activity_names(), 'act1')));
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_remove_activity_leaves_metadata_by_default(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md, 'act1');

            f.remove_activity('act1');

            testCase.verifyFalse(any(strcmp(f.get_activity_names(), 'act1')));
            testCase.verifyTrue(any(strcmp(f.get_metadata_names(), 'meta1')));
        end

        function test_remove_activity_can_delete_newly_unlinked_metadata(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md, 'act1');

            f.remove_activity('act1', true);

            testCase.verifyFalse(any(strcmp(f.get_activity_names(), 'act1')));
            testCase.verifyFalse(any(strcmp(f.get_metadata_names(), 'meta1')));
        end

        function test_remove_activity_keeps_metadata_if_linked_elsewhere(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            f.add_activity('act2', 'Activity two', when);

            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);
            f.link_activity_to_metadata('act1', 'meta1');
            f.link_activity_to_metadata('act2', 'meta1');

            f.remove_activity('act1', true);

            testCase.verifyFalse(any(strcmp(f.get_activity_names(), 'act1')));
            testCase.verifyTrue(any(strcmp(f.get_activity_names(), 'act2')));
            testCase.verifyTrue(any(strcmp(f.get_metadata_names(), 'meta1')));
            testCase.verifyTrue(any(strcmp(f.get_activity('act2').get_metadata_links(), 'meta1')));
        end

        function test_rename_metadata_updates_container_and_links(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md, 'act1');

            renamed = f.rename_metadata('meta1', 'meta2');

            testCase.verifyEqual(renamed.get_name(), 'meta2');
            testCase.verifyFalse(any(strcmp(f.get_metadata_names(), 'meta1')));
            testCase.verifyTrue(any(strcmp(f.get_metadata_names(), 'meta2')));
            testCase.verifyTrue(any(strcmp(f.get_activity('act1').get_metadata_links(), 'meta2')));
            testCase.verifyFalse(any(strcmp(f.get_activity('act1').get_metadata_links(), 'meta1')));
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_rename_metadata_rejects_invalid_name(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            did_error = false;
            try
                f.rename_metadata('meta1', 'not valid');
            catch
                did_error = true;
            end
            testCase.verifyTrue(did_error);
        end

        function test_rename_activity_updates_container(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            renamed = f.rename_activity('act1', 'act2');

            testCase.verifyEqual(renamed.get_name(), 'act2');
            testCase.verifyFalse(any(strcmp(f.get_activity_names(), 'act1')));
            testCase.verifyTrue(any(strcmp(f.get_activity_names(), 'act2')));
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_activity_rename_data_updates_activity(testCase)
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            activity.add_data(data);

            renamed = activity.rename_data('data1', 'data2');

            testCase.verifyEqual(renamed.get_name(), 'data2');
            testCase.verifyFalse(any(strcmp(activity.get_data_names(), 'data1')));
            testCase.verifyTrue(any(strcmp(activity.get_data_names(), 'data2')));
            testCase.verifyTrue(activity.get_has_pending_changes());
        end

        function test_container_rename_activity_data_delegates(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);

            renamed = f.rename_activity_data('act1', 'data1', 'data2');

            testCase.verifyEqual(renamed.get_name(), 'data2');
            testCase.verifyFalse(any(strcmp(f.get_activity('act1').get_data_names(), 'data1')));
            testCase.verifyTrue(any(strcmp(f.get_activity('act1').get_data_names(), 'data2')));
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_activity_replace_data_returns_removed_dataset(testCase)
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            original = escdf_ops_test.make_minimal_data('data1');
            original.value = 1.0;
            original.unit = {'g'};
            testCase.verifyTrue(original.validate());

            replacement = escdf_ops_test.make_minimal_data('data1');
            replacement.value = 9.81;
            replacement.unit = {'m/s^2'};
            testCase.verifyTrue(replacement.validate());

            activity.add_data(original);

            removed = activity.replace_data(replacement);

            testCase.verifyEqual(removed.get_name(), 'data1');
            testCase.verifyEqual(removed.value(:), single(1.0));

            current = activity.get_data('data1');
            testCase.verifyEqual(current.value(:), 9.81);
            testCase.verifyEqual(current.unit(:), {'m/s^2'});
            testCase.verifyTrue(activity.get_has_pending_changes());
        end

        function test_activity_replace_data_raises_if_missing(testCase)
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            replacement = escdf_ops_test.make_minimal_data('missing_data');
            replacement.value = 9.81;
            replacement.unit = {'m/s^2'};
            testCase.verifyTrue(replacement.validate());

            did_error = false;
            try
                activity.replace_data(replacement);
            catch
                did_error = true;
            end
            testCase.verifyTrue(did_error);
        end

        function test_container_replace_data_in_activity_returns_removed_dataset(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            original = escdf_ops_test.make_minimal_data('data1');
            original.value = 1.0;
            original.unit = {'g'};
            testCase.verifyTrue(original.validate());

            replacement = escdf_ops_test.make_minimal_data('data1');
            replacement.value = 9.81;
            replacement.unit = {'m/s^2'};
            testCase.verifyTrue(replacement.validate());

            f.add_data_to_activity('act1', original);
            removed = f.replace_data_in_activity('act1', replacement);

            testCase.verifyEqual(removed.value(:), single(1.0));

            current = f.get_activity_data('act1', 'data1');
            testCase.verifyEqual(current.value(:), 9.81);
            testCase.verifyEqual(current.unit(:), {'m/s^2'});
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_replace_metadata_returns_removed_dataset(testCase)
            f = escdf();

            original = escdf_ops_test.make_minimal_metadata('meta1');
            original.test_name = {'Original Test'};
            f.add_metadata(original);

            replacement = escdf_ops_test.make_minimal_metadata('meta1');
            replacement.test_name = {'Replacement Test'};

            removed = f.replace_metadata(replacement);

            testCase.verifyEqual(removed.test_name(:), {'Original Test'});
            current = f.get_metadata('meta1');
            testCase.verifyEqual(current.test_name(:), {'Replacement Test'});
            testCase.verifyTrue(f.get_has_pending_changes());
        end

        function test_replace_metadata_raises_if_missing(testCase)
            f = escdf();

            replacement = escdf_ops_test.make_minimal_metadata('missing_meta');

            did_error = false;
            try
                f.replace_metadata(replacement);
            catch
                did_error = true;
            end
            testCase.verifyTrue(did_error);
        end

        function test_activity_realize_to_hdf5_writes_datasets_and_links(testCase)
            outfile = fullfile(testCase.temp_folder, 'activity_realize.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
            activities_group = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);
            activity.link_to_metadata('meta1');

            data = escdf_ops_test.make_minimal_data('data1');
            data.value = 9.81;
            data.unit = {'m/s^2'};
            testCase.verifyTrue(data.validate());

            activity.add_data(data);

            activity.realize_to_hdf5(activities_group);

            testCase.verifyTrue(H5L.exists(activities_group, 'act1', 'H5P_DEFAULT') ~= 0);

            act_group = H5G.open(activities_group, 'act1');
            testCase.verifyTrue(H5L.exists(act_group, 'parameters', 'H5P_DEFAULT') ~= 0);
            testCase.verifyTrue(H5L.exists(act_group, 'data1', 'H5P_DEFAULT') ~= 0);

            data_group = H5G.open(act_group, 'data1');
            testCase.verifyTrue(H5L.exists(data_group, 'value', 'H5P_DEFAULT') ~= 0);
            testCase.verifyTrue(H5L.exists(data_group, 'unit', 'H5P_DEFAULT') ~= 0);
            H5G.close(data_group);

            testCase.verifyNotEmpty(activity.get_hdf5_location());
            testCase.verifyFalse(activity.get_has_pending_changes());

            H5G.close(act_group);
            H5G.close(activities_group);
            H5F.close(file_id);
        end

        function test_container_realize_to_hdf5_writes_metadata_and_activities(testCase)
            outfile = fullfile(testCase.temp_folder, 'container_realize.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);
            f.link_activity_to_metadata('act1', 'meta1');

            f.realize_to_hdf5(file_id);

            testCase.verifyTrue(H5L.exists(file_id, 'meta1', 'H5P_DEFAULT') ~= 0);
            testCase.verifyTrue(H5L.exists(file_id, 'activities', 'H5P_DEFAULT') ~= 0);

            agid = H5G.open(file_id, 'activities');
            testCase.verifyTrue(H5L.exists(agid, 'act1', 'H5P_DEFAULT') ~= 0);

            act_gid = H5G.open(agid, 'act1');
            testCase.verifyTrue(H5L.exists(act_gid, 'data1', 'H5P_DEFAULT') ~= 0);
            testCase.verifyTrue(H5L.exists(act_gid, 'parameters', 'H5P_DEFAULT') ~= 0);

            H5G.close(act_gid);
            H5G.close(agid);
            H5F.close(file_id);

            testCase.verifyNotEmpty(f.get_hdf5_location());
            testCase.verifyFalse(f.get_has_pending_changes());
        end

        function test_container_realize_to_hdf5_rejects_existing_group_without_overwrite(testCase)
            outfile = fullfile(testCase.temp_folder, 'container_realize_conflict.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            gid = H5G.create(file_id, 'meta1', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            H5G.close(gid);

            did_error = false;
            try
                f.realize_to_hdf5(file_id);
            catch
                did_error = true;
            end

            H5F.close(file_id);
            testCase.verifyTrue(did_error);
        end

        function test_get_metadata_returns_same_object_reference(testCase)
        % Verify repeated metadata retrieval returns the same stored object
        % wrapper, not a newly wrapped copy.
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            first = f.get_metadata('meta1');
            second = f.get_metadata('meta1');
            third = f.metadata(1);

            testCase.verifySameHandle(first, second);
            testCase.verifySameHandle(first, third);
        end

        function test_get_activity_returns_same_object_reference(testCase)
        % Verify repeated activity retrieval returns the same stored object
        % wrapper, not a newly wrapped copy.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            first = f.get_activity('act1');
            second = f.get_activity('act1');
            third = f.activities(1);

            testCase.verifySameHandle(first, second);
            testCase.verifySameHandle(first, third);
        end

        function test_get_activity_data_returns_same_object_reference(testCase)
        % Verify repeated activity-data retrieval returns the same stored
        % dataset object wrapper, not a newly wrapped copy.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);

            first = f.get_activity_data('act1', 'data1');
            second = f.get_activity_data('act1', 'data1');
            third = f.get_activity('act1').get_data('data1');

            testCase.verifySameHandle(first, second);
            testCase.verifySameHandle(first, third);
        end

        function test_activity_get_data_returns_same_object_reference(testCase)
        % Verify activity-level repeated data retrieval returns the same
        % stored dataset object wrapper.
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            activity.add_data(data);

            first = activity.get_data('data1');
            second = activity.get_data('data1');
            third = activity.data(1);

            testCase.verifySameHandle(first, second);
            testCase.verifySameHandle(first, third);
        end

        function test_metadata_dataset_logical_ancestry_is_bottom_up(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            attached_md = f.get_metadata('meta1');

            ancestry = attached_md.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 2);
            testCase.verifySameHandle(ancestry{1}, attached_md);
            testCase.verifySameHandle(ancestry{2}, f);
            testCase.verifySameHandle(attached_md.get_logical_root(), f);

            prop_ancestry = attached_md.test_name.get_logical_ancestry();
            testCase.verifyEqual(length(prop_ancestry), 3);
            testCase.verifySameHandle(prop_ancestry{1}, attached_md.test_name);
            testCase.verifySameHandle(prop_ancestry{2}, attached_md);
            testCase.verifySameHandle(prop_ancestry{3}, f);
            testCase.verifySameHandle(attached_md.test_name.get_logical_root(), f);
        end

        function test_activity_logical_ancestry_is_bottom_up(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            activity = f.get_activity('act1');

            ancestry = activity.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 2);
            testCase.verifySameHandle(ancestry{1}, activity);
            testCase.verifySameHandle(ancestry{2}, f);
            testCase.verifySameHandle(activity.get_logical_root(), f);
        end

        function test_activity_data_logical_ancestry_is_bottom_up(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);

            activity = f.get_activity('act1');
            attached_data = activity.get_data('data1');

            ancestry = attached_data.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 3);
            testCase.verifySameHandle(ancestry{1}, attached_data);
            testCase.verifySameHandle(ancestry{2}, activity);
            testCase.verifySameHandle(ancestry{3}, f);
            testCase.verifySameHandle(attached_data.get_logical_root(), f);

            prop_ancestry = attached_data.value.get_logical_ancestry();
            testCase.verifyEqual(length(prop_ancestry), 4);
            testCase.verifySameHandle(prop_ancestry{1}, attached_data.value);
            testCase.verifySameHandle(prop_ancestry{2}, attached_data);
            testCase.verifySameHandle(prop_ancestry{3}, activity);
            testCase.verifySameHandle(prop_ancestry{4}, f);
            testCase.verifySameHandle(attached_data.value.get_logical_root(), f);
        end

        function test_free_dataset_logical_ancestry_stops_at_dataset(testCase)
            ds = escdf_ops_test.make_minimal_metadata('free_meta');

            ancestry = ds.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 1);
            testCase.verifySameHandle(ancestry{1}, ds);
            testCase.verifySameHandle(ds.get_logical_root(), ds);

            prop_ancestry = ds.test_name.get_logical_ancestry();
            testCase.verifyEqual(length(prop_ancestry), 2);
            testCase.verifySameHandle(prop_ancestry{1}, ds.test_name);
            testCase.verifySameHandle(prop_ancestry{2}, ds);
            testCase.verifySameHandle(ds.test_name.get_logical_root(), ds);
        end

        function test_removed_objects_logical_ancestry_stops_after_detach(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            removed = f.remove_metadata('meta1');

            ancestry = removed.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 1);
            testCase.verifySameHandle(ancestry{1}, removed);
            testCase.verifySameHandle(removed.get_logical_root(), removed);

            prop_ancestry = removed.test_name.get_logical_ancestry();
            testCase.verifyEqual(length(prop_ancestry), 2);
            testCase.verifySameHandle(prop_ancestry{1}, removed.test_name);
            testCase.verifySameHandle(prop_ancestry{2}, removed);
            testCase.verifySameHandle(removed.test_name.get_logical_root(), removed);
        end

        function test_container_logical_ancestry_is_self(testCase)
        % Verify that a top-level ESCDF container has no logical parent and
        % its ancestry/root are itself.
            f = escdf();

            testCase.verifyEmpty(f.get_logical_parent());

            ancestry = f.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 1);
            testCase.verifySameHandle(ancestry{1}, f);
            testCase.verifySameHandle(f.get_logical_root(), f);
        end

        function test_metadata_dataset_logical_parent_after_add_metadata(testCase)
        % Verify that metadata added to a container has the container as
        % logical parent and that its properties have the dataset as logical
        % parent.
            f = escdf();
            source_md = escdf_ops_test.make_minimal_metadata('meta1');

            testCase.verifyEmpty(source_md.get_logical_parent());

            f.add_metadata(source_md);
            attached_md = f.get_metadata('meta1');

            testCase.verifyFalse(attached_md == source_md);
            testCase.verifySameHandle(attached_md.get_logical_parent(), f);

            testCase.verifySameHandle(attached_md.test_name.get_logical_parent(), attached_md);
            testCase.verifySameHandle(attached_md.program.get_logical_parent(), attached_md);
            testCase.verifySameHandle(attached_md.hardware_list.get_logical_parent(), attached_md);
            testCase.verifySameHandle(attached_md.point_of_contact.get_logical_parent(), attached_md);
        end

        function test_activity_logical_parent_after_add_activity(testCase)
        % Verify that activities added to a container have the container as
        % logical parent.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');

            f.add_activity('act1', 'Activity one', when);
            activity = f.get_activity('act1');

            testCase.verifySameHandle(activity.get_logical_parent(), f);
        end

        function test_activity_data_logical_parent_after_add_data(testCase)
        % Verify that activity data added to an activity has the activity
        % as logical parent and its properties have the dataset as logical
        % parent.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            testCase.verifyEmpty(data.get_logical_parent());

            f.add_data_to_activity('act1', data);

            activity = f.get_activity('act1');
            attached_data = activity.get_data('data1');

            testCase.verifyFalse(attached_data == data);
            testCase.verifySameHandle(attached_data.get_logical_parent(), activity);

            testCase.verifySameHandle(attached_data.value.get_logical_parent(), attached_data);
            testCase.verifySameHandle(attached_data.unit.get_logical_parent(), attached_data);
        end

        function test_removed_metadata_logical_ancestry_stops_after_detach(testCase)
        % Verify that removed metadata is detached from the container but
        % its properties still logically belong to the removed dataset.
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            removed = f.remove_metadata('meta1');

            testCase.verifyEmpty(removed.get_logical_parent());

            ancestry = removed.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 1);
            testCase.verifySameHandle(ancestry{1}, removed);
            testCase.verifySameHandle(removed.get_logical_root(), removed);

            prop_ancestry = removed.test_name.get_logical_ancestry();
            testCase.verifyEqual(length(prop_ancestry), 2);
            testCase.verifySameHandle(prop_ancestry{1}, removed.test_name);
            testCase.verifySameHandle(prop_ancestry{2}, removed);
            testCase.verifySameHandle(removed.test_name.get_logical_root(), removed);
        end

        function test_removed_activity_logical_ancestry_stops_after_detach(testCase)
        % Verify that removed activities are detached from the container.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            removed = f.remove_activity('act1');

            testCase.verifyEmpty(removed.get_logical_parent());

            ancestry = removed.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 1);
            testCase.verifySameHandle(ancestry{1}, removed);
            testCase.verifySameHandle(removed.get_logical_root(), removed);
        end

        function test_removed_activity_data_logical_ancestry_stops_after_detach(testCase)
        % Verify that removed activity data is detached from the activity
        % while its properties still logically belong to the removed
        % dataset.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);

            removed = f.remove_data_from_activity('act1', 'data1');

            testCase.verifyEmpty(removed.get_logical_parent());

            ancestry = removed.get_logical_ancestry();
            testCase.verifyEqual(length(ancestry), 1);
            testCase.verifySameHandle(ancestry{1}, removed);
            testCase.verifySameHandle(removed.get_logical_root(), removed);

            prop_ancestry = removed.value.get_logical_ancestry();
            testCase.verifyEqual(length(prop_ancestry), 2);
            testCase.verifySameHandle(prop_ancestry{1}, removed.value);
            testCase.verifySameHandle(prop_ancestry{2}, removed);
            testCase.verifySameHandle(removed.value.get_logical_root(), removed);
        end

        function test_metadata_logical_parent_after_add_metadata(testCase)
        % Verify that metadata added to a container has the container as
        % logical parent and that its properties have the metadata dataset
        % as logical parent.
            f = escdf();
            source_md = escdf_ops_test.make_minimal_metadata('meta1');

            testCase.verifyEmpty(source_md.get_logical_parent());

            f.add_metadata(source_md);
            attached_md = f.get_metadata('meta1');

            % add_metadata clones the dataset wrapper before insertion.
            testCase.verifyFalse(attached_md == source_md);
            testCase.verifySameHandle(attached_md.get_logical_parent(), f);

            property_names = properties(attached_md);
            for i = 1:length(property_names)
                property_name = property_names{i};
                if startsWith(property_name, 'DO_NOT_USE_')
                    continue
                end

                prop = attached_md.(property_name);
                if isa(prop, 'escdf_property')
                    testCase.verifySameHandle(prop.get_logical_parent(), attached_md);
                end
            end
        end

        function test_removed_metadata_becomes_free(testCase)
        % Verify that removed metadata no longer has a logical parent.
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            removed = f.remove_metadata('meta1');

            testCase.verifyEmpty(removed.get_logical_parent());
        end

        function test_removed_activity_becomes_free(testCase)
        % Verify that a removed activity no longer has a logical parent.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            removed = f.remove_activity('act1');

            testCase.verifyEmpty(removed.get_logical_parent());
        end

        function test_removed_activity_data_becomes_free(testCase)
        % Verify that removed activity data no longer has a logical parent.
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);

            removed = f.remove_data_from_activity('act1', 'data1');

            testCase.verifyEmpty(removed.get_logical_parent());
        end

        function test_same_logical_location_for_same_retrieved_metadata(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            first = f.get_metadata('meta1');
            second = f.get_metadata('meta1');

            testCase.verifyTrue(first.same_logical_location_as(second));
            testCase.verifyTrue(first.test_name.same_logical_location_as(second.test_name));
        end

        function test_same_logical_location_true_for_self_after_remove(testCase)
            f = escdf();
            f.add_metadata(escdf_ops_test.make_minimal_metadata('meta1'));

            removed = f.remove_metadata('meta1');

            testCase.verifyEmpty(removed.get_logical_parent());
            testCase.verifyTrue(removed.same_logical_location_as(removed));
        end

        function test_logical_paths_for_metadata_dataset_and_property(testCase)
            f = escdf();
            md = escdf_ops_test.make_minimal_metadata('meta1');
            f.add_metadata(md);

            attached_md = f.get_metadata('meta1');

            testCase.verifyEqual(f.get_logical_path(), '/');
            testCase.verifyEqual(attached_md.get_logical_path(), '/meta1');
            testCase.verifyEqual(attached_md.test_name.get_logical_path(), '/meta1/test_name');
        end

        function test_logical_paths_for_activity_data_and_property(testCase)
            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);

            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);

            activity = f.get_activity('act1');
            attached_data = activity.get_data('data1');

            testCase.verifyEqual(activity.get_logical_path(), '/activities/act1');
            testCase.verifyEqual(attached_data.get_logical_path(), '/activities/act1/data1');
            testCase.verifyEqual(attached_data.value.get_logical_path(), '/activities/act1/data1/value');
        end

        function test_free_objects_have_no_logical_path(testCase)
            ds = escdf_ops_test.make_minimal_metadata('free_meta');

            testCase.verifyEmpty(ds.get_logical_path());
            testCase.verifyEmpty(ds.test_name.get_logical_path());
        end

        function test_same_logical_location_requires_same_root(testCase)
            f1 = escdf();
            f2 = escdf();

            f1.add_metadata(escdf_ops_test.make_minimal_metadata('meta1'));
            f2.add_metadata(escdf_ops_test.make_minimal_metadata('meta1'));

            md1 = f1.get_metadata('meta1');
            md2 = f2.get_metadata('meta1');

            testCase.verifyEqual(md1.get_logical_path(), md2.get_logical_path());
            testCase.verifyFalse(md1.same_logical_location_as(md2));
            testCase.verifyFalse(md1.test_name.same_logical_location_as(md2.test_name));
        end

        function test_same_logical_location_for_repeated_retrieval(testCase)
            f = escdf();
            f.add_metadata(escdf_ops_test.make_minimal_metadata('meta1'));

            first = f.get_metadata('meta1');
            second = f.get_metadata('meta1');

            testCase.verifySameHandle(first, second);
            testCase.verifyTrue(first.same_logical_location_as(second));
            testCase.verifyTrue(first.test_name.same_logical_location_as(second.test_name));
        end

        function test_activity_hdf5_location_is_empty_for_memory_activity(testCase)
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            testCase.verifyTrue(isempty(activity.get_hdf5_location()));
        end

        function test_loaded_activity_hdf5_location_matches_group(testCase)
            outfile = fullfile(testCase.temp_folder, 'activity_location.h5');

            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);
            activity = loaded.get_activity('act1');

            location = activity.get_hdf5_location();
            testCase.verifyFalse(isempty(location));
            testCase.verifyEqual(location.object_path, '/activities/act1');
        end

        function test_activity_same_backing_location_for_two_wrappers(testCase)
            outfile = fullfile(testCase.temp_folder, 'activity_same_backing.h5');

            f = escdf();
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            f.add_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            f.add_data_to_activity('act1', data);
            f.write_to_disk(outfile, true);

            loaded1 = escdf.load(outfile);
            loaded2 = escdf.load(outfile);

            act1 = loaded1.get_activity('act1');
            act2 = loaded2.get_activity('act1');

            testCase.verifyFalse(act1 == act2);
            testCase.verifyTrue(act1.same_backing_location_as(act2));
        end

        function test_activity_target_hdf5_location_uses_activities_group(testCase)
            file_id = H5F.create(fullfile(testCase.temp_folder, 'activity_target_location.h5'), ...
                'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
            activities_group = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);

            location = activity.get_target_hdf5_location(activities_group);

            testCase.verifyEqual(location.object_path, '/activities/act1');

            H5G.close(activities_group);
            H5F.close(file_id);
        end

        function test_activity_is_realized_at_true_after_realization(testCase)
            file_id = H5F.create(fullfile(testCase.temp_folder, 'activity_realized_at.h5'), ...
                'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
            activities_group = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');
            activity = escdf_activity('act1', 'Activity one', when);
            data = escdf_ops_test.make_minimal_data('data1');
            activity.add_data(data);

            activity.realize_to_hdf5(activities_group);

            act_group = H5G.open(activities_group, 'act1');

            testCase.verifyTrue(activity.is_realized_under(activities_group));
            testCase.verifyTrue(activity.is_realized_at(act_group));

            H5G.close(act_group);
            H5G.close(activities_group);
            H5F.close(file_id);
        end

        function test_container_hdf5_location_is_empty_for_memory_container(testCase)
            f = escdf();

            testCase.verifyTrue(isempty(f.get_hdf5_location()));
        end

        function test_loaded_container_hdf5_location_matches_file(testCase)
            outfile = fullfile(testCase.temp_folder, 'container_location.h5');

            f = escdf();
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);

            location = loaded.get_hdf5_location();
            testCase.verifyFalse(isempty(location));
            testCase.verifyEqual(location.object_path, '/');
        end

        function test_container_same_backing_location_for_two_wrappers(testCase)
            outfile = fullfile(testCase.temp_folder, 'container_same_backing.h5');

            f = escdf();
            f.write_to_disk(outfile, true);

            loaded1 = escdf.load(outfile);
            loaded2 = escdf.load(outfile);

            testCase.verifyFalse(loaded1 == loaded2);
            testCase.verifyTrue(loaded1.same_backing_location_as(loaded2));
        end

        function test_container_is_realized_at_true_after_realization(testCase)
            outfile = fullfile(testCase.temp_folder, 'container_realized_at.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            f = escdf();
            f.realize_to_hdf5(file_id);

            testCase.verifyTrue(f.is_realized_at(file_id));

            H5F.close(file_id);
        end

    end
end