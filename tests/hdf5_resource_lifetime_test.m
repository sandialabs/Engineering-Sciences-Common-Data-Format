classdef hdf5_resource_lifetime_test < matlab.unittest.TestCase
% HDF5_RESOURCE_LIFETIME_TEST Check MATLAB HDF5 identifier ownership.
%
% These tests compare open HDF5 object counts against a controlled
% observer-file baseline. Returned IDs are diagnostic only and are never
% closed by the tests.

    properties
        temp_folder
        original_path
    end

    methods (TestMethodSetup)
        function setup_environment(testCase)
        % Create a temporary folder and make ESCDF classes available.
            test_folder = fileparts(mfilename('fullpath'));
            source_folder = fullfile(test_folder, '..', 'escdf');

            testCase.temp_folder = tempname;
            mkdir(testCase.temp_folder);
            testCase.original_path = addpath(genpath(source_folder));
        end
    end

    methods (TestMethodTeardown)
        function teardown_environment(testCase)
        % Restore the path and remove temporary test files.
            path(testCase.original_path);
            if isfolder(testCase.temp_folder)
                rmdir(testCase.temp_folder, 's');
            end
        end
    end

    methods (Static, Access=private)
        function create_property_file(path)
        % Create a file containing one valid ESCDF property at /p1.
        %
        % Parameters
        % ----------
        % path : char
        %     Output HDF5 file path.
            file_id = H5F.create( ...
                path, 'H5F_ACC_TRUNC', ...
                'H5P_DEFAULT', 'H5P_DEFAULT');
            file_cleanup = onCleanup(@() H5F.close(file_id)); %#ok<NASGU>

            prop = escdf_property('p1', 'f8', [3]);
            prop(:) = [1.0; 2.0; 3.0];
            prop.realize_to_hdf5(file_id);

            % The property owns the dataset ID created by realization.
            % Release it before the file-creation scope ends.
            delete(prop);
        end

        function assert_open_count(testCase, file_id, expected)
        % Assert an HDF5 object count, displaying open IDs on failure.
        %
        % Parameters
        % ----------
        % testCase : matlab.unittest.TestCase
        %     Current test case.
        % file_id : numeric
        %     Observer HDF5 file identifier.
        % expected : numeric
        %     Expected count of open file-associated objects.
            actual = H5F.get_obj_count(file_id, 'H5F_OBJ_ALL');

            if actual ~= expected
                ids = H5F.get_obj_ids( ...
                    file_id, 'H5F_OBJ_ALL', actual);
                diagnostic = sprintf( ...
                    'Expected %d open HDF5 objects; found %d.\nOpen IDs:\n%s', ...
                    expected, actual, evalc('disp(ids)'));
                testCase.verifyEqual(actual, expected, diagnostic);
            else
                testCase.verifyEqual(actual, expected);
            end
        end
    end

    methods (Test)
        function test_path_based_property_load_releases_temporary_file_id(testCase)
        % Loading retains one dataset ID but not the temporary file ID.
            path = fullfile(testCase.temp_folder, 'property_load.h5');
            hdf5_resource_lifetime_test.create_property_file(path);

            observer_id = H5F.open( ...
                path, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
            observer_cleanup = onCleanup( ...
                @() H5F.close(observer_id)); %#ok<NASGU>

            baseline = H5F.get_obj_count(observer_id, 'H5F_OBJ_ALL');

            prop = escdf_property.load([path, '::/p1'], true);
            hdf5_resource_lifetime_test.assert_open_count( ...
                testCase, observer_id, baseline + 1);

            testCase.verifyEqual(prop(:), [1.0; 2.0; 3.0]);

            delete(prop);
            hdf5_resource_lifetime_test.assert_open_count( ...
                testCase, observer_id, baseline);
        end

        function test_clone_owns_independent_dataset_id(testCase)
        % Releasing a clone must not close its source property's ID.
            path = fullfile(testCase.temp_folder, 'clone_handles.h5');
            hdf5_resource_lifetime_test.create_property_file(path);

            observer_id = H5F.open( ...
                path, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
            observer_cleanup = onCleanup( ...
                @() H5F.close(observer_id)); %#ok<NASGU>

            baseline = H5F.get_obj_count(observer_id, 'H5F_OBJ_ALL');

            source = escdf_property.load([path, '::/p1'], true);
            with_source = H5F.get_obj_count( ...
                observer_id, 'H5F_OBJ_ALL');
            testCase.verifyEqual(with_source, baseline + 1);

            container = escdf();
            clone = container.clone_property_for_attach(source);

            testCase.verifyFalse(source == clone);
            testCase.verifyTrue(source.same_backing_location_as(clone));
            hdf5_resource_lifetime_test.assert_open_count( ...
                testCase, observer_id, with_source + 1);

            delete(clone);
            hdf5_resource_lifetime_test.assert_open_count( ...
                testCase, observer_id, with_source);

            testCase.verifyFalse(source.is_closed());
            testCase.verifyEqual(source(:), [1.0; 2.0; 3.0]);

            delete(source);
            hdf5_resource_lifetime_test.assert_open_count( ...
                testCase, observer_id, baseline);
        end

        function test_completed_top_level_write_leaves_no_target_ids(testCase)
        % The public write closes its target datasets and file ID.
            path = fullfile(testCase.temp_folder, 'complete_write.h5');

            container = escdf();
            metadata = escdf_dataset( ...
                'meta1', 'scalar', 'Scalar metadata');
            metadata.value = 2.0;
            metadata.unit = {'g'};
            container.add_metadata(metadata);

            container.write_to_disk(path, true);

            observer_id = H5F.open( ...
                path, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
            observer_cleanup = onCleanup( ...
                @() H5F.close(observer_id)); %#ok<NASGU>

            % Only the observer ID should remain for this file.
            hdf5_resource_lifetime_test.assert_open_count( ...
                testCase, observer_id, 1);

            testCase.verifyTrue( ...
                container.get_metadata('meta1').value.is_closed());
        end
    end
end