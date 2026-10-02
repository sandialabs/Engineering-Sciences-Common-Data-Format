import os
import numpy as np
import escdf
import pytest


def test_set_and_extract_attachments_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    src1 = tmp_path / "hello.bin"
    src2 = tmp_path / "numbers.bin"

    src1.write_bytes(b"hello world")
    src2.write_bytes(bytes([1, 2, 3, 4, 5, 255]))

    md = escdf.Dataset(
        "global_meta_with_attachments",
        "global_test_attributes",
        "Global metadata with attachments",
    )
    md.test_name = "Attachment Test"
    md.program = "Program Bytes"
    md.hardware_list = ["hardware_1"]
    md.point_of_contact = ["person_1"]
    md.set_attachments([str(src1), str(src2)])

    assert md.validate()

    f = escdf.ESCDF()
    f.add_metadata(md)

    escdf_path = tmp_path / "attachments_roundtrip.h5"
    f.write_to_disk(str(escdf_path))

    loaded = escdf.ESCDF.load(str(escdf_path))
    loaded_md = loaded.metadata["global_meta_with_attachments"]

    outdir = tmp_path / "extracted"
    outdir.mkdir()
    loaded_md.dump_attachments_to_disk(str(outdir))

    assert (outdir / "hello.bin").read_bytes() == b"hello world"
    assert (outdir / "numbers.bin").read_bytes() == bytes([1, 2, 3, 4, 5, 255])

    np.testing.assert_array_equal(
        loaded_md.attachment_names[...],
        np.array(["hello.bin", "numbers.bin"], dtype=object),
    )


def test_list_attachment_names_returns_all_names(tmp_path):
    src1 = tmp_path / "hello.bin"
    src2 = tmp_path / "numbers.bin"
    src1.write_bytes(b"hello world")
    src2.write_bytes(bytes([1, 2, 3, 4, 5, 255]))

    md = escdf.Dataset("global_meta_with_attachments", "global_test_attributes")
    md.test_name = "test program name"
    md.program = "program abc"
    md.hardware_list = ["instr 1", "instr 2"]
    md.point_of_contact = ["tom", "jerry"]
    md.set_attachments([str(src1), str(src2)])

    assert md.list_attachment_names() == ["hello.bin", "numbers.bin"]


def test_get_attachment_index_returns_expected_index(tmp_path):
    src1 = tmp_path / "hello.bin"
    src2 = tmp_path / "numbers.bin"
    src1.write_bytes(b"hello world")
    src2.write_bytes(bytes([1, 2, 3, 4, 5, 255]))

    md = escdf.Dataset("global_meta_with_attachments", "global_test_attributes")
    md.test_name = "test program name"
    md.program = "program abc"
    md.hardware_list = ["instr 1", "instr 2"]
    md.point_of_contact = ["tom", "jerry"]
    md.set_attachments([str(src1), str(src2)])

    assert md.get_attachment_index("hello.bin") == 0
    assert md.get_attachment_index("numbers.bin") == 1


def test_get_attachment_index_raises_for_missing_name(tmp_path):
    src1 = tmp_path / "hello.bin"
    src1.write_bytes(b"hello world")

    md = escdf.Dataset("global_meta_with_attachments", "global_test_attributes")
    md.test_name = "test program name"
    md.program = "program abc"
    md.hardware_list = ["instr 1", "instr 2"]
    md.point_of_contact = ["tom", "jerry"]
    md.set_attachments([str(src1)])

    with pytest.raises(ValueError, match='No attachment named "missing.bin"'):
        md.get_attachment_index("missing.bin")


def test_dump_attachment_to_disk_writes_single_attachment(tmp_path):
    src1 = tmp_path / "hello.bin"
    src2 = tmp_path / "numbers.bin"
    src1.write_bytes(b"hello world")
    src2.write_bytes(bytes([1, 2, 3, 4, 5, 255]))

    md = escdf.Dataset("global_meta_with_attachments", "global_test_attributes")
    md.test_name = "test program name"
    md.program = "program abc"
    md.hardware_list = ["instr 1", "instr 2"]
    md.point_of_contact = ["tom", "jerry"]
    md.set_attachments([str(src1), str(src2)])

    outdir = tmp_path / "single_extract"
    outdir.mkdir()

    md.dump_attachment_to_disk("numbers.bin", str(outdir))

    assert not (outdir / "hello.bin").exists()
    assert (outdir / "numbers.bin").exists()
    assert (outdir / "numbers.bin").read_bytes() == bytes([1, 2, 3, 4, 5, 255])
