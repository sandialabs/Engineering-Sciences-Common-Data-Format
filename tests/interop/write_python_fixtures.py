import os
import datetime as dt
from datetime import timezone
import numpy as np
import h5py

import escdf

# Prevent interactive prompting in CI / script execution
escdf.ESCDF.get_or_prompt_attribution_name = staticmethod(
    lambda **kwargs: "interop_test_user"
)

def make_simple_scalar_file(output_path: str):
    f = escdf.ESCDF()

    created_time = dt.datetime(2025, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)
    activity_time = dt.datetime(2025, 6, 7, 8, 9, 10, 654321, tzinfo=timezone.utc)
    f.set_created_properties("interop_test_user", created_time)

    md = escdf.Dataset("global_meta", "global_test_attributes", "Global test metadata")
    md.test_name = "Qualification Test"
    md.program = "Program ABC"
    md.hardware_list = ["hardware_1", "hardware_2"]
    md.point_of_contact = ["person_1", "person_2"]

    data = escdf.Dataset("scalar_result", "scalar", "Scalar activity result")
    data.value = 9.81
    data.unit = "m/s^2"

    f.add_metadata(md)
    f.add_activity("act1", "Activity One", activity_time)
    f.link_activity_to_metadata("act1", "global_meta")
    f.add_data_to_activity("act1", data)

    f.write_to_disk(output_path, clobber=True)


def make_numeric_arrays_file(output_path: str):
    f = escdf.ESCDF()

    created_time = dt.datetime(2025, 3, 4, 5, 6, 7, 234567, tzinfo=timezone.utc)
    activity_time = dt.datetime(2025, 8, 9, 10, 11, 12, 345678, tzinfo=timezone.utc)
    f.set_created_properties("interop_test_user", created_time)

    md = escdf.Dataset("geometry_meta", "geometry", "Geometry metadata")
    md.node_id = np.array([10, 20, 30], dtype=np.uint64)
    md.node_position = np.array(
        [
            [0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
        ],
        dtype=np.float64,
    )
    md.node_x_direction = np.array(
        [
            [1.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
        ],
        dtype=np.float64,
    )
    md.node_y_direction = np.array(
        [
            [0.0, 1.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 1.0, 0.0],
        ],
        dtype=np.float64,
    )
    md.node_z_direction = np.array(
        [
            [0.0, 0.0, 1.0],
            [0.0, 0.0, 1.0],
            [0.0, 0.0, 1.0],
        ],
        dtype=np.float64,
    )
    md.position_units = "m"

    vector_result = escdf.Dataset("vector_result", "vector", "Vector activity result")
    vector_result.value = np.array([1.0, 2.0, 3.5, 4.5], dtype=np.float64)
    vector_result.unit = "m/s^2"

    matrix_result = escdf.Dataset("matrix_result", "matrix", "Matrix activity result")
    matrix_result.value = np.array(
        [
            [1.0, 2.0],
            [3.0, 4.5],
            [6.0, 7.0],
        ],
        dtype=np.float64,
    )
    matrix_result.unit = "N"

    f.add_metadata(md)
    f.add_activity("act_arrays", "Array activity", activity_time)
    f.link_activity_to_metadata("act_arrays", "geometry_meta")
    f.add_data_to_activity("act_arrays", vector_result)
    f.add_data_to_activity("act_arrays", matrix_result)

    f.write_to_disk(output_path, clobber=True)

def make_invalid_names_file(output_path: str):
    with h5py.File(output_path, "w") as f:
        f.attrs["created_by"] = "interop_test_user"
        f.attrs["created_date"] = "2025-04-05T06:07:08.111111Z"

        md = f.create_group("1 bad-meta")
        md.attrs["_specification_name"] = "scalar"
        md.attrs["_descriptive_name"] = "Bad metadata"
        md.attrs["_version"] = (0, 1, 0)

        value = md.create_dataset("value", shape=(), dtype="f8")
        value.attrs["data_type"] = "f8"
        value[()] = 1.23

        unit = md.create_dataset("unit", shape=(), dtype=h5py.string_dtype())
        unit.attrs["data_type"] = "str"
        unit[()] = "g"

        activities = f.create_group("activities")
        act = activities.create_group("1 bad-activity")
        act.attrs["activity_name"] = "Bad activity"
        act.attrs["activity_date"] = "2025-09-10T11:12:13.222222Z"

        parameters = act.create_dataset("parameters", shape=(1,), dtype=h5py.string_dtype())
        parameters.attrs["data_type"] = "str"
        parameters[0] = "1 bad-meta"


def make_unknown_type_file(output_path: str):
    with h5py.File(output_path, "w") as f:
        f.attrs["created_by"] = "interop_test_user"
        f.attrs["created_date"] = "2025-04-05T06:07:08.333333Z"
        f.create_group("activities")

        md = f.create_group("mystery_metadata")
        md.attrs["_specification_name"] = "totally_unknown_type"
        md.attrs["_descriptive_name"] = "Mystery metadata"
        md.attrs["_version"] = (9, 9, 9)

        original = md.create_dataset("original_type_name", shape=(), dtype=h5py.string_dtype())
        original.attrs["data_type"] = "str"
        original[()] = "totally_unknown_type"

def make_attachments_bytes_file(output_path: str):
    f = escdf.ESCDF()

    created_time = dt.datetime(2025, 5, 6, 7, 8, 9, 444444, tzinfo=timezone.utc)
    f.set_created_properties("interop_test_user", created_time)

    md = escdf.Dataset(
        "global_meta_with_attachments",
        "global_test_attributes",
        "Global metadata with attachments",
    )
    md.test_name = "Attachment Test"
    md.program = "Program Bytes"
    md.hardware_list = ["hardware_1"]
    md.point_of_contact = ["person_1"]

    md.attachment_names = ["hello.bin", "numbers.bin"]
    md.attachments = np.array(
        [
            np.frombuffer(b"hello world", dtype=np.uint8),
            np.array([1, 2, 3, 4, 5, 255], dtype=np.uint8),
        ],
        dtype=object,
    )

    f.add_metadata(md)
    f.write_to_disk(output_path, clobber=True)

def make_complex_data_file(output_path: str):
    f = escdf.ESCDF()

    created_time = dt.datetime(2025, 10, 11, 12, 13, 14, 555555, tzinfo=timezone.utc)
    activity_time = dt.datetime(2025, 10, 12, 13, 14, 15, 666666, tzinfo=timezone.utc)
    f.set_created_properties("interop_test_user", created_time)

    scalar_result = escdf.Dataset(
        "complex_scalar_result",
        "scalar",
        "Complex scalar activity result",
    )
    scalar_result.value = np.complex128(1.5 - 2.25j)
    scalar_result.unit = "V"

    vector_result = escdf.Dataset(
        "complex_vector_result",
        "vector",
        "Complex vector activity result",
    )
    vector_result.value = np.array(
        [1.0 + 2.0j, -3.0 + 0.5j, -1.0j, 4.25 + 3.0j],
        dtype=np.complex128,
    )
    vector_result.unit = "m/s"

    matrix_result = escdf.Dataset(
        "complex_matrix_result",
        "matrix",
        "Complex matrix activity result",
    )
    matrix_result.value = np.array(
        [
            [1.0 + 1.0j, 2.0 - 2.0j],
            [-3.0 + 0.5j, 4.0 + 4.0j],
            [-1.0j, 6.0 + 0.0j],
        ],
        dtype=np.complex128,
    )
    matrix_result.unit = "N"

    f.add_activity("act_complex", "Complex activity", activity_time)
    f.add_data_to_activity("act_complex", scalar_result)
    f.add_data_to_activity("act_complex", vector_result)
    f.add_data_to_activity("act_complex", matrix_result)

    f.write_to_disk(output_path, clobber=True)

def make_ragged_numeric_file(output_path: str):
    f = escdf.ESCDF()

    created_time = dt.datetime(2025, 11, 1, 2, 3, 4, 777777, tzinfo=timezone.utc)
    f.set_created_properties("interop_test_user", created_time)

    md = escdf.Dataset(
        "geometry_ragged_meta",
        "geometry",
        "Geometry with ragged connectivity",
    )

    md.node_id = np.array([10, 20, 30, 40, 50], dtype=np.uint64)
    md.node_position = np.array(
        [
            [0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [2.0, 0.5, 0.0],
            [3.0, 1.0, 0.0],
            [4.0, 1.5, 0.0],
        ],
        dtype=np.float64,
    )
    md.node_x_direction = np.tile(np.array([[1.0, 0.0, 0.0]], dtype=np.float64), (5, 1))
    md.node_y_direction = np.tile(np.array([[0.0, 1.0, 0.0]], dtype=np.float64), (5, 1))
    md.node_z_direction = np.tile(np.array([[0.0, 0.0, 1.0]], dtype=np.float64), (5, 1))

    md.line_connection = np.array(
        [
            np.array([10, 20], dtype=np.uint64),
            np.array([20, 30, 40], dtype=np.uint64),
            np.array([40, 50], dtype=np.uint64),
        ],
        dtype=object,
    )

    md.element_connection = np.array(
        [
            np.array([10, 20, 30], dtype=np.uint64),
            np.array([20, 30, 40, 50], dtype=np.uint64),
        ],
        dtype=object,
    )

    md.element_type = np.array(["tri3", "quad4"], dtype=object)
    md.position_units = "m"

    f.add_metadata(md)
    f.write_to_disk(output_path, clobber=True)

def make_extra_property_file(output_path: str):
    with h5py.File(output_path, "w") as f:
        f.attrs["created_by"] = "interop_test_user"
        f.attrs["created_date"] = "2025-12-01T01:02:03.888888Z"
        f.create_group("activities")

        md = f.create_group("meta_with_extra")
        md.attrs["_specification_name"] = "scalar"
        md.attrs["_descriptive_name"] = "Scalar metadata with extra field"
        md.attrs["_version"] = (0, 1, 0)

        value = md.create_dataset("value", shape=(), dtype="f8")
        value.attrs["data_type"] = "f8"
        value[()] = 2.0

        unit = md.create_dataset("unit", shape=(), dtype=h5py.string_dtype())
        unit.attrs["data_type"] = "str"
        unit[()] = "g"

        extra = md.create_dataset("unexpected_field", shape=(3,), dtype="f8")
        extra.attrs["data_type"] = "f8"
        extra[...] = np.array([10.0, 20.0, 30.0], dtype=np.float64)

def main():
    outdir = os.path.join("ci_artifacts", "interop", "python_written")
    os.makedirs(outdir, exist_ok=True)

    make_simple_scalar_file(
        os.path.join(outdir, "simple_scalar_python_written.h5")
    )
    make_numeric_arrays_file(
        os.path.join(outdir, "numeric_arrays_python_written.h5")
    )
    make_invalid_names_file(
        os.path.join(outdir, "invalid_names_python_written.h5")
    )
    make_unknown_type_file(
        os.path.join(outdir, "unknown_type_python_written.h5")
    )

    make_attachments_bytes_file(
        os.path.join(outdir, "attachments_bytes_python_written.h5")
    )

    make_complex_data_file(
        os.path.join(outdir, "complex_data_python_written.h5")
    )

    make_ragged_numeric_file(
        os.path.join(outdir, "ragged_numeric_python_written.h5")
    )

    make_extra_property_file(
        os.path.join(outdir, "extra_property_python_written.h5")
    )

if __name__ == "__main__":
    main()