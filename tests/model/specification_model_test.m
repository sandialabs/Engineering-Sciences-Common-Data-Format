classdef specification_model_test < matlab.unittest.TestCase
% SPECIFICATION_MODEL_TEST Tests for the canonical ESCDF specification model.
%
% This test class exercises the new canonical specification parser and
% registry machinery against both the packaged ESCDF specifications and
% small synthetic specifications.

    properties
        temp_folder
        original_path
        source_folder
        model_folder
    end

    methods (TestMethodSetup)
        function setupEnvironment(testCase)
            current_file_folder = fileparts(mfilename('fullpath'));
            testCase.source_folder = fullfile(current_file_folder, '..', 'escdf');
            testCase.model_folder = fullfile(testCase.source_folder, 'model');
            testCase.temp_folder = tempname;
            testCase.original_path = addpath(testCase.source_folder, testCase.model_folder);
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

    methods (Test)
        function test_build_default_registry_loads_packaged_specs(testCase)
            registry = SpecificationRegistry.build_default_registry();

            testCase.verifyClass(registry, 'SpecificationRegistry');

            local_names = registry.list_local_names();
            testCase.verifyGreaterThan(numel(local_names), 0);

            expected_names = { ...
                'parameter_set', ...
                'activity_result', ...
                'scalar', ...
                'data', ...
                'geometry', ...
                'channel_table', ...
                'global_test_attributes'};

            for i = 1:numel(expected_names)
                testCase.verifyTrue(any(strcmp(local_names, expected_names{i})));
            end
        end

        function test_resolve_parameter_set(testCase)
            registry = SpecificationRegistry.build_default_registry();
            resolved = registry.resolve('parameter_set');

            testCase.verifyClass(resolved, 'ResolvedSpecification');
            testCase.verifyEqual(resolved.name, 'parameter_set');
            testCase.verifyClass(resolved.version, 'Version');

            testCase.verifyEqual(resolved.ancestry, {'parameter_set'});

            testCase.verifyTrue(any(strcmp(resolved.property_names, 'notes')));
            testCase.verifyTrue(any(strcmp(resolved.property_names, 'attachments')));
            testCase.verifyTrue(any(strcmp(resolved.property_names, 'attachment_names')));

            testCase.verifyTrue(isKey(resolved.properties_by_name, 'notes'));
            testCase.verifyTrue(isKey(resolved.properties_by_name, 'attachments'));
            testCase.verifyTrue(isKey(resolved.properties_by_name, 'attachment_names'));
        end

        function test_resolve_activity_result_inherits_parameter_set(testCase)
            registry = SpecificationRegistry.build_default_registry();
            resolved = registry.resolve('activity_result');

            testCase.verifyClass(resolved, 'ResolvedSpecification');
            testCase.verifyEqual(resolved.name, 'activity_result');

            testCase.verifyEqual(resolved.ancestry, {'parameter_set', 'activity_result'});

            testCase.verifyTrue(any(strcmp(resolved.property_names, 'notes')));
            testCase.verifyTrue(any(strcmp(resolved.property_names, 'attachments')));
            testCase.verifyTrue(any(strcmp(resolved.property_names, 'attachment_names')));
        end

        function test_resolve_scalar_has_expected_choice_group(testCase)
            registry = SpecificationRegistry.build_default_registry();
            resolved = registry.resolve('scalar');

            testCase.verifyTrue(isKey(resolved.choice_groups, 'value'));

            branches = resolved.choice_groups('value');
            expected_branches = { ...
                'real_single_precision', ...
                'complex_single_precision', ...
                'real_double_precision', ...
                'complex_double_precision'};

            for i = 1:numel(expected_branches)
                branch_name = expected_branches{i};
                testCase.verifyTrue(isKey(branches, branch_name));

                branch_properties = branches(branch_name);
                testCase.verifyEqual(numel(branch_properties), 1);
                testCase.verifyEqual(branch_properties(1).name, 'value');
                testCase.verifyEqual(branch_properties(1).choice_group, 'value');
                testCase.verifyEqual(branch_properties(1).choice_branch, branch_name);
            end
        end

        function test_resolve_data_has_expected_dimension_names(testCase)
            registry = SpecificationRegistry.build_default_registry();
            resolved = registry.resolve('data');

            expected_dimensions = {'num_data', 'num_samples', 'num_channels'};
            for i = 1:numel(expected_dimensions)
                testCase.verifyTrue(any(strcmp(resolved.dimension_names, expected_dimensions{i})));
            end
        end

        function test_resolve_geometry_has_variable_length_connectivity(testCase)
            registry = SpecificationRegistry.build_default_registry();
            resolved = registry.resolve('geometry');

            testCase.verifyTrue(isKey(resolved.properties_by_name, 'line_connection'));
            line_connection_defs = resolved.properties_by_name('line_connection');
            testCase.verifyEqual(numel(line_connection_defs), 1);

            line_connection = line_connection_defs(1);
            testCase.verifyClass(line_connection, 'PropertyDefinition');
            testCase.verifyTrue(line_connection.variable_length);
        end

        function test_resolve_channel_table_preserves_enumerations(testCase)
            registry = SpecificationRegistry.build_default_registry();
            resolved = registry.resolve('channel_table');

            testCase.verifyTrue(isKey(resolved.enumerations, 'data_types'));
            values = resolved.enumerations('data_types');

            testCase.verifyTrue(any(strcmp(values, 'acceleration')));
            testCase.verifyTrue(any(strcmp(values, 'force')));
            testCase.verifyTrue(any(strcmp(values, 'temperature')));
        end

        function test_parser_lifts_requires_constraint_from_property_option(testCase)
            spec_text = sprintf([ ...
                'mini_requires - v0.1.0\n', ...
                '----------------------\n', ...
                'extends: none\n', ...
                '\n', ...
                'properties\n', ...
                '----------\n', ...
                'attachments - bytes - num_attachments - optional,requires:attachment_names\n', ...
                'attachment_names - str - num_attachments - optional,requires:attachments\n']);

            spec_file = fullfile(testCase.temp_folder, 'mini_requires.txt');
            fid = fopen(spec_file, 'w');
            fwrite(fid, spec_text, 'char');
            fclose(fid);

            spec = SpecificationParser.parse_file(spec_file);

            testCase.verifyClass(spec, 'Specification');
            testCase.verifyEqual(spec.name, 'mini_requires');
            testCase.verifyEqual(spec.extends, '');
            testCase.verifyClass(spec.version, 'Version');

            testCase.verifyEqual(numel(spec.local_properties), 2);
            property_names = arrayfun(@(p) p.name, spec.local_properties, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(property_names, 'attachments')));
            testCase.verifyTrue(any(strcmp(property_names, 'attachment_names')));

            attachments_prop = spec.local_properties(strcmp(property_names, 'attachments'));
            attachment_names_prop = spec.local_properties(strcmp(property_names, 'attachment_names'));

            testCase.verifyTrue(attachments_prop.optional);
            testCase.verifyTrue(attachment_names_prop.optional);

            testCase.verifyEqual(attachments_prop.shape_repr(), 'num_attachments');
            testCase.verifyEqual(attachment_names_prop.shape_repr(), 'num_attachments');

            testCase.verifyEqual(numel(spec.constraints), 2);
            testCase.verifyTrue(all(arrayfun(@(r) isa(r, 'ConstraintRule'), spec.constraints)));

            subject_target_pairs = cell(1, numel(spec.constraints));
            source_properties = cell(1, numel(spec.constraints));
            for i = 1:numel(spec.constraints)
                rule = spec.constraints(i);
                subject_target_pairs{i} = sprintf('%s->%s', ...
                    rule.subject_properties{1}, rule.target_properties{1});
                source_properties{i} = rule.source_property;
            end

            testCase.verifyTrue(any(strcmp(subject_target_pairs, 'attachments->attachment_names')));
            testCase.verifyTrue(any(strcmp(subject_target_pairs, 'attachment_names->attachments')));

            testCase.verifyTrue(any(strcmp(source_properties, 'attachments')));
            testCase.verifyTrue(any(strcmp(source_properties, 'attachment_names')));
        end

        function test_parser_normalizes_scalar_shape(testCase)
            spec_text = sprintf([ ...
                'mini_scalar - v0.1.0\n', ...
                '--------------------\n', ...
                'extends: none\n', ...
                '\n', ...
                'properties\n', ...
                '----------\n', ...
                'value - f8 - scalar\n']);

            spec = SpecificationParser.parse_text(spec_text);

            testCase.verifyEqual(numel(spec.local_properties), 1);
            prop = spec.local_properties(1);
            testCase.verifyClass(prop, 'PropertyDefinition');
            testCase.verifyEqual(prop.name, 'value');
            testCase.verifyTrue(prop.is_scalar());
            testCase.verifyTrue(isempty(prop.shape));
        end

        function test_parser_normalizes_fixed_and_symbolic_dimensions(testCase)
            spec_text = sprintf([ ...
                'mini_dims - v0.1.0\n', ...
                '------------------\n', ...
                'extends: none\n', ...
                '\n', ...
                'properties\n', ...
                '----------\n', ...
                'node_position - f8 - num_nodes,3\n']);

            spec = SpecificationParser.parse_text(spec_text);

            prop = spec.local_properties(1);
            testCase.verifyEqual(numel(prop.shape), 2);

            dim0 = prop.shape(1);
            dim1 = prop.shape(2);

            testCase.verifyClass(dim0, 'Dimension');
            testCase.verifyClass(dim1, 'Dimension');

            testCase.verifyTrue(dim0.is_symbolic());
            testCase.verifyEqual(dim0.value, 'num_nodes');

            testCase.verifyTrue(dim1.is_fixed());
            testCase.verifyEqual(dim1.value, 3);
        end
    end
end