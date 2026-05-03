import pytest

from docunderstand.main import main


@pytest.mark.unit
def test_main_runs(capsys):
    main()
    captured = capsys.readouterr()
    assert "docunderstand" in captured.out
