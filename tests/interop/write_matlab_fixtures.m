function write_matlab_fixtures()
    addpath(fullfile(pwd, "escdf"));

    cfgPath = escdf.escdf_config_path();
    cfg = struct();
    cfg.attribution_name = char('test');
    cfg.schema_version = 1;
    cfg.updated_utc = char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
    escdf.escdf_save_config(cfgPath, cfg);

    outdir = fullfile(pwd, "ci_artifacts", "interop", "matlab_written");
    if ~isfolder(outdir)
        mkdir(outdir);
    end

    outfile = fullfile(outdir, "simple_scalar_matlab_written.h5");

    f = escdf();

    created_time = datetime(2025,1,2,3,4,5.123456,'TimeZone','UTC');
    activity_time = datetime(2025,6,7,8,9,10.654321,'TimeZone','UTC');
    f.set_created_properties('interop_test_user', created_time);

    md = escdf_dataset('global_meta', 'global_test_attributes', 'Global test metadata');
    md.test_name = {'Qualification Test'};
    md.program = {'Program ABC'};
    md.hardware_list = {'hardware_1'; 'hardware_2'};
    md.point_of_contact = {'person_1'; 'person_2'};

    data = escdf_dataset('scalar_result', 'scalar', 'Scalar activity result');
    data.value = 9.81;
    data.unit = {'m/s^2'};

    f.add_metadata(md);
    f.add_activity('act1', 'Activity One', activity_time);
    f.link_activity_to_metadata('act1', 'global_meta');
    f.add_data_to_activity('act1', data);

    f.write_to_disk(outfile, true);

    outfile = fullfile(outdir, "numeric_arrays_matlab_written.h5");

    f = escdf();

    created_time = datetime(2025,3,4,5,6,7.234567,'TimeZone','UTC');
    activity_time = datetime(2025,8,9,10,11,12.345678,'TimeZone','UTC');
    f.set_created_properties('interop_test_user', created_time);

    md = escdf_dataset('geometry_meta', 'geometry', 'Geometry metadata');
    md.node_id = uint64([10;20;30]);
    md.node_position = [
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
    ];
    md.node_x_direction = [
        1.0 0.0 0.0
        1.0 0.0 0.0
        1.0 0.0 0.0
    ];
    md.node_y_direction = [
        0.0 1.0 0.0
        0.0 1.0 0.0
        0.0 1.0 0.0
    ];
    md.node_z_direction = [
        0.0 0.0 1.0
        0.0 0.0 1.0
        0.0 0.0 1.0
    ];
    md.position_units = {'m'};

    vector_result = escdf_dataset('vector_result', 'vector', 'Vector activity result');
    vector_result.value = [1.0; 2.0; 3.5; 4.5];
    vector_result.unit = {'m/s^2'};

    matrix_result = escdf_dataset('matrix_result', 'matrix', 'Matrix activity result');
    matrix_result.value = [
        1.0 2.0
        3.0 4.5
        6.0 7.0
    ];
    matrix_result.unit = {'N'};

    f.add_metadata(md);
    f.add_activity('act_arrays', 'Array activity', activity_time);
    f.link_activity_to_metadata('act_arrays', 'geometry_meta');
    f.add_data_to_activity('act_arrays', vector_result);
    f.add_data_to_activity('act_arrays', matrix_result);

    f.write_to_disk(outfile, true);

    outfile = fullfile(outdir, "invalid_names_matlab_written.h5");
    write_invalid_names_fixture(outfile);

    outfile = fullfile(outdir, "unknown_type_matlab_written.h5");
    write_unknown_type_fixture(outfile);

    outfile = fullfile(outdir, "attachments_bytes_matlab_written.h5");

    f = escdf();

    created_time = datetime(2025,5,6,7,8,9.444444,'TimeZone','UTC');
    f.set_created_properties('interop_test_user', created_time);

    md = escdf_dataset( ...
        'global_meta_with_attachments', ...
        'global_test_attributes', ...
        'Global metadata with attachments');

    md.test_name = {'Attachment Test'};
    md.program = {'Program Bytes'};
    md.hardware_list = {'hardware_1'};
    md.point_of_contact = {'person_1'};

    md.attachment_names = {'hello.bin'; 'numbers.bin'};
    md.attachments = {
        uint8('hello world').'
        uint8([1;2;3;4;5;255])
    };

    f.add_metadata(md);
    f.write_to_disk(outfile, true);

    outfile = fullfile(outdir, "complex_data_matlab_written.h5");

    f = escdf();

    created_time = datetime(2025,10,11,12,13,14.555555,'TimeZone','UTC');
    activity_time = datetime(2025,10,12,13,14,15.666666,'TimeZone','UTC');
    f.set_created_properties('interop_test_user', created_time);

    scalar_result = escdf_dataset( ...
        'complex_scalar_result', ...
        'scalar', ...
        'Complex scalar activity result');
    scalar_result.value = 1.5 - 2.25j;
    scalar_result.unit = {'V'};

    vector_result = escdf_dataset( ...
        'complex_vector_result', ...
        'vector', ...
        'Complex vector activity result');
    vector_result.value = [
        1.0 + 2.0j
        -3.0 + 0.5j
        -1.0j
        4.25 + 3.0j
    ];
    vector_result.unit = {'m/s'};

    matrix_result = escdf_dataset( ...
        'complex_matrix_result', ...
        'matrix', ...
        'Complex matrix activity result');
    matrix_result.value = [
        1.0 + 1.0j, 2.0 - 2.0j
        -3.0 + 0.5j, 4.0 + 4.0j
        -1.0j, 6.0 + 0.0j
    ];
    matrix_result.unit = {'N'};

    f.add_activity('act_complex', 'Complex activity', activity_time);
    f.add_data_to_activity('act_complex', scalar_result);
    f.add_data_to_activity('act_complex', vector_result);
    f.add_data_to_activity('act_complex', matrix_result);

    f.write_to_disk(outfile, true);

    outfile = fullfile(outdir, "ragged_numeric_matlab_written.h5");

    f = escdf();

    created_time = datetime(2025,11,1,2,3,4.777777,'TimeZone','UTC');
    f.set_created_properties('interop_test_user', created_time);

    md = escdf_dataset( ...
        'geometry_ragged_meta', ...
        'geometry', ...
        'Geometry with ragged connectivity');

    md.node_id = uint64([10;20;30;40;50]);
    md.node_position = [
        0.0 0.0 0.0
        1.0 0.0 0.0
        2.0 0.5 0.0
        3.0 1.0 0.0
        4.0 1.5 0.0
    ];
    md.node_x_direction = repmat([1.0 0.0 0.0],5,1);
    md.node_y_direction = repmat([0.0 1.0 0.0],5,1);
    md.node_z_direction = repmat([0.0 0.0 1.0],5,1);

    md.line_connection = {
        uint64([10;20])
        uint64([20;30;40])
        uint64([40;50])
    };

    md.element_connection = {
        uint64([10;20;30])
        uint64([20;30;40;50])
    };

    md.element_type = {'tri3'; 'quad4'};
    md.position_units = {'m'};

    f.add_metadata(md);
    f.write_to_disk(outfile, true);

    outfile = fullfile(outdir, "extra_property_matlab_written.h5");
    write_extra_property_fixture(outfile);

end

function write_invalid_names_fixture(outfile)
    file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

    write_string_attribute(file_id, 'created_by', 'interop_test_user');
    write_string_attribute(file_id, 'created_date', '2025-04-05T06:07:08.111111Z');

    % metadata with invalid name
    gid = H5G.create(file_id, '1 bad-meta', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    write_string_attribute(gid, '_specification_name', 'scalar');
    write_string_attribute(gid, '_descriptive_name', 'Bad metadata');
    write_version_attribute(gid, [0 1 0]);

    value_space = H5S.create('H5S_SCALAR');
    value_did = H5D.create(gid, 'value', 'H5T_IEEE_F64LE', value_space, 'H5P_DEFAULT');
    H5D.write(value_did, 'H5T_IEEE_F64LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 1.23);
    write_string_attribute(value_did, 'data_type', 'f8');
    H5D.close(value_did);
    H5S.close(value_space);

    unit_space = H5S.create('H5S_SCALAR');
    str_type_id = H5T.copy('H5T_C_S1');
    H5T.set_size(str_type_id, 'H5T_VARIABLE');
    unit_did = H5D.create(gid, 'unit', str_type_id, unit_space, 'H5P_DEFAULT');
    H5D.write(unit_did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'g');
    write_string_attribute(unit_did, 'data_type', 'str');
    H5D.close(unit_did);
    H5T.close(str_type_id);
    H5S.close(unit_space);

    H5G.close(gid);

    % activity with invalid name
    activities_gid = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    act_gid = H5G.create(activities_gid, '1 bad-activity', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

    write_string_attribute(act_gid, 'activity_name', 'Bad activity');
    write_string_attribute(act_gid, 'activity_date', '2025-09-10T11:12:13.222222Z');

    space_id = H5S.create_simple(1, 1, []);
    str_type_id = H5T.copy('H5T_C_S1');
    H5T.set_size(str_type_id, 'H5T_VARIABLE');
    did = H5D.create(act_gid, 'parameters', str_type_id, space_id, 'H5P_DEFAULT');
    H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', {'1 bad-meta'});
    write_string_attribute(did, 'data_type', 'str');

    H5D.close(did);
    H5T.close(str_type_id);
    H5S.close(space_id);

    H5G.close(act_gid);
    H5G.close(activities_gid);
    H5F.close(file_id);
end


function write_unknown_type_fixture(outfile)
    file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

    write_string_attribute(file_id, 'created_by', 'interop_test_user');
    write_string_attribute(file_id, 'created_date', '2025-04-05T06:07:08.333333Z');

    H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

    gid = H5G.create(file_id, 'mystery_metadata', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    write_string_attribute(gid, '_specification_name', 'totally_unknown_type');
    write_string_attribute(gid, '_descriptive_name', 'Mystery metadata');
    write_version_attribute(gid, [9 9 9]);

    space_id = H5S.create('H5S_SCALAR');
    str_type_id = H5T.copy('H5T_C_S1');
    H5T.set_size(str_type_id, 'H5T_VARIABLE');
    did = H5D.create(gid, 'original_type_name', str_type_id, space_id, 'H5P_DEFAULT');
    H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'totally_unknown_type');
    write_string_attribute(did, 'data_type', 'str');

    H5D.close(did);
    H5T.close(str_type_id);
    H5S.close(space_id);

    H5G.close(gid);
    H5F.close(file_id);
end


function write_string_attribute(loc_id, attr_name, value)
    attr_space_id = H5S.create('H5S_SCALAR');
    str_type_id = H5T.copy('H5T_C_S1');
    H5T.set_size(str_type_id, 'H5T_VARIABLE');
    attr_id = H5A.create(loc_id, attr_name, str_type_id, attr_space_id, 'H5P_DEFAULT');
    H5A.write(attr_id, str_type_id, value);
    H5A.close(attr_id);
    H5T.close(str_type_id);
    H5S.close(attr_space_id);
end


function write_version_attribute(loc_id, version_numbers)
    attr_type = H5T.copy('H5T_NATIVE_INT');
    attr_space = H5S.create_simple(1, numel(version_numbers), []);
    attr_id = H5A.create(loc_id, '_version', attr_type, attr_space, 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5A.write(attr_id, attr_type, int32(version_numbers));
    H5A.close(attr_id);
    H5S.close(attr_space);
end

function write_extra_property_fixture(outfile)
    file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

    write_string_attribute(file_id, 'created_by', 'interop_test_user');
    write_string_attribute(file_id, 'created_date', '2025-12-01T01:02:03.888888Z');

    H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

    gid = H5G.create(file_id, 'meta_with_extra', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    write_string_attribute(gid, '_specification_name', 'scalar');
    write_string_attribute(gid, '_descriptive_name', 'Scalar metadata with extra field');
    write_version_attribute(gid, [0 1 0]);

    value_space = H5S.create('H5S_SCALAR');
    value_did = H5D.create(gid, 'value', 'H5T_IEEE_F64LE', value_space, 'H5P_DEFAULT');
    H5D.write(value_did, 'H5T_IEEE_F64LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 2.0);
    write_string_attribute(value_did, 'data_type', 'f8');
    H5D.close(value_did);
    H5S.close(value_space);

    unit_space = H5S.create('H5S_SCALAR');
    str_type_id = H5T.copy('H5T_C_S1');
    H5T.set_size(str_type_id, 'H5T_VARIABLE');
    unit_did = H5D.create(gid, 'unit', str_type_id, unit_space, 'H5P_DEFAULT');
    H5D.write(unit_did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'g');
    write_string_attribute(unit_did, 'data_type', 'str');
    H5D.close(unit_did);
    H5T.close(str_type_id);
    H5S.close(unit_space);

    extra_space = H5S.create_simple(1, 3, []);
    extra_did = H5D.create(gid, 'unexpected_field', 'H5T_IEEE_F64LE', extra_space, 'H5P_DEFAULT');
    H5D.write(extra_did, 'H5T_IEEE_F64LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', [10.0 20.0 30.0]);
    write_string_attribute(extra_did, 'data_type', 'f8');
    H5D.close(extra_did);
    H5S.close(extra_space);

    H5G.close(gid);
    H5F.close(file_id);
end