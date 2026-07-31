using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;
using ComDataObject = System.Runtime.InteropServices.ComTypes.IDataObject;
using ComFormatEtc = System.Runtime.InteropServices.ComTypes.FORMATETC;
using Forms = System.Windows.Forms;

namespace NaiLauncher.OleDragInspector;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        Forms.Application.EnableVisualStyles();
        Forms.Application.SetCompatibleTextRenderingDefault(false);
        var outputRoot = CommandLine.ReadValue(args, "--output")
            ?? Path.Combine(
                Path.GetTempPath(),
                "nai_launcher_ole_drag_inspector",
                $"session_{DateTime.UtcNow:yyyyMMdd_HHmmss}_{Guid.NewGuid():N}");
        outputRoot = Path.GetFullPath(outputRoot);
        Directory.CreateDirectory(outputRoot);
        if (args.Any(argument =>
            string.Equals(argument, "--self-test", StringComparison.OrdinalIgnoreCase)))
        {
            OleDataInspector.RunSelfTest(outputRoot);
            return;
        }
        Forms.Application.Run(new InspectorForm(outputRoot));
    }
}

internal static class CommandLine
{
    public static string? ReadValue(string[] args, string name)
    {
        for (var index = 0; index < args.Length - 1; index++)
        {
            if (string.Equals(args[index], name, StringComparison.OrdinalIgnoreCase))
            {
                return args[index + 1];
            }
        }

        return null;
    }
}

internal sealed class InspectorForm : Forms.Form
{
    private static readonly string[] Paths =
    [
        "history_prepared_file",
        "preview_memory_only",
        "preview_source_file",
        "gallery_drag_wrapper",
    ];

    private readonly string _outputRoot;
    private readonly Forms.ComboBox _mode = CreateCombo(["protected", "unprotected"]);
    private readonly Forms.ComboBox _path = CreateCombo(Paths);
    private readonly Forms.ComboBox _payload = CreateCombo(["text", "stealth"]);
    private readonly Forms.Label _status = new()
    {
        AutoSize = true,
        Text = "Ready. Select the matrix cell, then drop one launcher image.",
    };
    private readonly Forms.Panel _dropTarget = new()
    {
        AllowDrop = true,
        BackColor = Color.FromArgb(18, 59, 58),
        BorderStyle = Forms.BorderStyle.FixedSingle,
        Dock = Forms.DockStyle.Fill,
        MinimumSize = new Size(620, 300),
    };
    private int _sequence;

    public InspectorForm(string outputRoot)
    {
        _outputRoot = outputRoot;
        Text = "NAI Launcher OLE Drag Inspector";
        MinimumSize = new Size(760, 560);
        StartPosition = Forms.FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10);

        var output = new Forms.TextBox
        {
            ReadOnly = true,
            Dock = Forms.DockStyle.Fill,
            Text = outputRoot,
        };
        var openOutput = new Forms.Button { Text = "Open output", AutoSize = true };
        openOutput.Click += (_, _) => Process.Start(
            new ProcessStartInfo("explorer.exe", outputRoot) { UseShellExecute = true });

        var controls = new Forms.TableLayoutPanel
        {
            Dock = Forms.DockStyle.Top,
            AutoSize = true,
            ColumnCount = 6,
            Padding = new Forms.Padding(10),
        };
        controls.ColumnStyles.Add(new Forms.ColumnStyle(Forms.SizeType.AutoSize));
        controls.ColumnStyles.Add(new Forms.ColumnStyle(Forms.SizeType.Percent, 33));
        controls.ColumnStyles.Add(new Forms.ColumnStyle(Forms.SizeType.AutoSize));
        controls.ColumnStyles.Add(new Forms.ColumnStyle(Forms.SizeType.Percent, 34));
        controls.ColumnStyles.Add(new Forms.ColumnStyle(Forms.SizeType.AutoSize));
        controls.ColumnStyles.Add(new Forms.ColumnStyle(Forms.SizeType.Percent, 33));
        controls.Controls.Add(new Forms.Label { Text = "Mode", AutoSize = true }, 0, 0);
        controls.Controls.Add(_mode, 1, 0);
        controls.Controls.Add(new Forms.Label { Text = "Path", AutoSize = true }, 2, 0);
        controls.Controls.Add(_path, 3, 0);
        controls.Controls.Add(new Forms.Label { Text = "Payload", AutoSize = true }, 4, 0);
        controls.Controls.Add(_payload, 5, 0);
        controls.Controls.Add(new Forms.Label { Text = "Session", AutoSize = true }, 0, 1);
        controls.Controls.Add(output, 1, 1);
        controls.SetColumnSpan(output, 4);
        controls.Controls.Add(openOutput, 5, 1);

        var targetLabel = new Forms.Label
        {
            AutoSize = false,
            Dock = Forms.DockStyle.Fill,
            ForeColor = Color.White,
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Segoe UI Semibold", 18, FontStyle.Bold),
            Text = "DROP LAUNCHER IMAGE HERE\r\n\r\nEvery advertised OLE format will be read.",
        };
        _dropTarget.Controls.Add(targetLabel);
        _dropTarget.DragEnter += OnDragEnter;
        _dropTarget.DragOver += OnDragEnter;
        _dropTarget.DragDrop += OnDragDrop;

        var statusPanel = new Forms.FlowLayoutPanel
        {
            Dock = Forms.DockStyle.Bottom,
            AutoSize = true,
            Padding = new Forms.Padding(10),
        };
        statusPanel.Controls.Add(_status);

        Controls.Add(_dropTarget);
        Controls.Add(statusPanel);
        Controls.Add(controls);
    }

    private static Forms.ComboBox CreateCombo(string[] values)
    {
        var combo = new Forms.ComboBox
        {
            DropDownStyle = Forms.ComboBoxStyle.DropDownList,
            Dock = Forms.DockStyle.Fill,
        };
        combo.Items.AddRange(values);
        combo.SelectedIndex = 0;
        return combo;
    }

    private void OnDragEnter(object? sender, Forms.DragEventArgs eventArgs)
    {
        eventArgs.Effect = eventArgs.Data is null
            ? Forms.DragDropEffects.None
            : Forms.DragDropEffects.Copy;
    }

    private void OnDragDrop(object? sender, Forms.DragEventArgs eventArgs)
    {
        if (eventArgs.Data is null)
        {
            SetStatus("FAILED: Windows supplied no IDataObject.", passed: false);
            return;
        }

        var mode = (string)_mode.SelectedItem!;
        var path = (string)_path.SelectedItem!;
        var payload = (string)_payload.SelectedItem!;
        var cellDirectory = Path.Combine(
            _outputRoot,
            $"{++_sequence:D2}_{path}_{mode}_{payload}");
        Directory.CreateDirectory(cellDirectory);

        try
        {
            var manifest = OleDataInspector.Inspect(
                eventArgs.Data,
                cellDirectory,
                mode,
                path,
                payload);
            SetStatus(
                manifest.InspectionPassed
                    ? $"PASS: {manifest.Formats.Count} formats fully read into {cellDirectory}"
                    : $"FAILED CLOSED: inspect manifest in {cellDirectory}",
                manifest.InspectionPassed);
        }
        catch (Exception exception)
        {
            var failure = new DropManifest
            {
                Mode = mode,
                Path = path,
                Payload = payload,
                InspectionPassed = false,
                FatalError = exception.ToString(),
            };
            ManifestWriter.Write(cellDirectory, failure);
            SetStatus($"FAILED CLOSED: {exception.Message}", passed: false);
        }
    }

    private void SetStatus(string message, bool passed)
    {
        _status.Text = message;
        _status.ForeColor = passed ? Color.DarkGreen : Color.DarkRed;
    }
}

internal static class OleDataInspector
{
    private const long MaximumPayloadBytes = 512L * 1024 * 1024;

    private static readonly HashSet<string> ControlFormats = new(
        StringComparer.OrdinalIgnoreCase)
    {
        "Preferred DropEffect",
        "Performed DropEffect",
        "Paste Succeeded",
        "InShellDragLoop",
        "UsingDefaultDragImage",
        "IsShowingLayered",
        "DragSourceHelperFlags",
        "DragWindow",
        "DragContext",
        "DragSource",
        "DropDescription",
        "Shell IDList Array",
        "FileGroupDescriptor",
        "FileGroupDescriptorW",
        "FileContents",
    };

    public static void RunSelfTest(string outputRoot)
    {
        var cellDirectory = Path.Combine(outputRoot, "self_test");
        Directory.CreateDirectory(cellDirectory);
        using var bitmap = new Bitmap(4, 3, PixelFormat.Format32bppArgb);
        bitmap.SetPixel(0, 0, Color.FromArgb(255, 18, 59, 58));
        using var bmpStream = new MemoryStream();
        bitmap.Save(bmpStream, ImageFormat.Bmp);
        var bmpBytes = bmpStream.ToArray();
        var dib = new byte[bmpBytes.Length - 14];
        Buffer.BlockCopy(bmpBytes, 14, dib, 0, dib.Length);
        using var decoded = Image.FromStream(new MemoryStream(WrapDibAsBmp(dib)));
        if (decoded.Width != bitmap.Width || decoded.Height != bitmap.Height)
        {
            throw new InvalidDataException("DIB self-test changed image dimensions.");
        }

        var format = new FormatManifest
        {
            Index = 0,
            FormatId = 8,
            FormatName = "DeviceIndependentBitmap",
            AdvertisedTymed = TYMED.TYMED_HGLOBAL.ToString(),
            ActualTymed = TYMED.TYMED_HGLOBAL.ToString(),
            Aspect = DVASPECT.DVASPECT_CONTENT.ToString(),
            Lindex = -1,
            Classification = "image",
            IsImageCandidate = true,
            Status = "complete",
            ReleaseStgMediumCalled = true,
        };
        ReadBinaryPayload(dib, format, cellDirectory, "self_test");
        var bitmapHandle = bitmap.GetHbitmap();
        try
        {
            using var captured = CaptureHBitmap(bitmapHandle, bitmap.Width, bitmap.Height);
            SaveDecodedImage(captured, format, cellDirectory, "self_test_hbitmap");
        }
        finally
        {
            NativeMethods.DeleteObject(bitmapHandle);
        }
        var manifest = new DropManifest
        {
            Mode = "self_test",
            Path = "self_test",
            Payload = "self_test",
            ProcessBitness = Environment.Is64BitProcess ? 64 : 32,
            InspectionPassed = format.DecodedImages.Count == 2,
        };
        manifest.Formats.Add(format);
        ManifestWriter.Write(cellDirectory, manifest);
        if (!manifest.InspectionPassed)
        {
            throw new InvalidDataException("Image dump self-test did not decode its DIB.");
        }
        File.WriteAllText(
            Path.Combine(outputRoot, "self_test_passed.txt"),
            "OLE inspector self-test passed.",
            new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
    }

    public static DropManifest Inspect(
        Forms.IDataObject formsDataObject,
        string cellDirectory,
        string mode,
        string path,
        string payload)
    {
        if (formsDataObject is not ComDataObject dataObject)
        {
            throw new InvalidOperationException(
                $"The WinForms IDataObject wrapper does not expose COM IDataObject: " +
                formsDataObject.GetType().FullName);
        }

        var manifest = new DropManifest
        {
            Mode = mode,
            Path = path,
            Payload = payload,
            ProcessBitness = Environment.Is64BitProcess ? 64 : 32,
        };

        IEnumFORMATETC? enumerator = null;
        try
        {
            enumerator = dataObject.EnumFormatEtc(DATADIR.DATADIR_GET);
            var formatBuffer = new ComFormatEtc[1];
            var fetched = new int[1];
            var index = 0;
            while (true)
            {
                fetched[0] = 0;
                var resultCode = enumerator.Next(1, formatBuffer, fetched);
                if (resultCode == 1 && fetched[0] == 0)
                {
                    break;
                }
                if (resultCode != 0 || fetched[0] != 1)
                {
                    if (resultCode < 0)
                    {
                        Marshal.ThrowExceptionForHR(resultCode);
                    }
                    throw new InvalidDataException(
                        $"EnumFormatEtc returned HRESULT 0x{resultCode:X8} " +
                        $"with fetched={fetched[0]}.");
                }

                var format = formatBuffer[0];
                var result = InspectFormat(
                    dataObject,
                    format,
                    index++,
                    cellDirectory);
                manifest.Formats.Add(result);
            }
        }
        finally
        {
            if (enumerator is not null && Marshal.IsComObject(enumerator))
            {
                Marshal.FinalReleaseComObject(enumerator);
            }
        }

        manifest.InspectionPassed = manifest.Formats.Count > 0
            && manifest.Formats.All(format =>
                format.Status == "complete"
                && format.Classification != "unknown"
                && (!format.IsImageCandidate || format.DecodedImages.Count > 0));
        ManifestWriter.Write(cellDirectory, manifest);
        return manifest;
    }

    private static FormatManifest InspectFormat(
        ComDataObject dataObject,
        ComFormatEtc format,
        int index,
        string cellDirectory)
    {
        var formatId = unchecked((ushort)format.cfFormat);
        var formatName = Forms.DataFormats.GetFormat(formatId).Name;
        var classification = Classify(formatId, formatName);
        var result = new FormatManifest
        {
            Index = index,
            FormatId = formatId,
            FormatName = formatName,
            AdvertisedTymed = format.tymed.ToString(),
            Aspect = format.dwAspect.ToString(),
            Lindex = format.lindex,
            Classification = classification,
            IsImageCandidate = classification == "image",
        };

        STGMEDIUM medium = default;
        var receivedMedium = false;
        try
        {
            dataObject.GetData(ref format, out medium);
            receivedMedium = true;
            result.ActualTymed = medium.tymed.ToString();
            ReadMedium(medium, result, cellDirectory);
            if (result.IsImageCandidate && result.DecodedImages.Count == 0)
            {
                throw new InvalidDataException(
                    $"Image-like format {formatName} was read but could not be decoded.");
            }

            result.Status = "complete";
        }
        catch (Exception exception)
        {
            result.Status = "failed";
            result.Error = exception.ToString();
        }
        finally
        {
            if (receivedMedium)
            {
                NativeMethods.ReleaseStgMedium(ref medium);
                result.ReleaseStgMediumCalled = true;
            }
        }

        return result;
    }

    private static string Classify(int formatId, string formatName)
    {
        if (formatId is 2 or 8 or 17
            || ContainsIgnoreCase(formatName, "DragImageBits")
            || formatName.Equals("PNG", StringComparison.OrdinalIgnoreCase)
            || formatName.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            || ContainsIgnoreCase(formatName, "bitmap")
            || ContainsIgnoreCase(formatName, "dib"))
        {
            return "image";
        }

        if (formatId == 15
            || formatName.Equals("FileDrop", StringComparison.OrdinalIgnoreCase)
            || formatName.StartsWith("FileName", StringComparison.OrdinalIgnoreCase))
        {
            return "file-list";
        }

        if (ContainsIgnoreCase(formatName, "UniformResourceLocator")
            || formatName.Equals("text/uri-list", StringComparison.OrdinalIgnoreCase))
        {
            return "uri-list";
        }

        if (formatId is 1 or 7 or 13
            || ContainsIgnoreCase(formatName, "text"))
        {
            return "text";
        }

        return ControlFormats.Contains(formatName) ? "control" : "unknown";
    }

    private static void ReadMedium(
        STGMEDIUM medium,
        FormatManifest result,
        string cellDirectory)
    {
        switch (medium.tymed)
        {
            case TYMED.TYMED_HGLOBAL:
                ReadBinaryPayload(
                    ReadHGlobal(medium.unionmember),
                    result,
                    cellDirectory,
                    "hglobal");
                break;
            case TYMED.TYMED_ISTREAM:
                ReadBinaryPayload(
                    ReadComStream(medium.unionmember),
                    result,
                    cellDirectory,
                    "istream");
                break;
            case TYMED.TYMED_FILE:
                ReadTymedFile(medium.unionmember, result, cellDirectory);
                break;
            case TYMED.TYMED_GDI:
                using (var image = CaptureHBitmap(medium.unionmember))
                {
                    SaveDecodedImage(image, result, cellDirectory, "gdi");
                }
                break;
            case TYMED.TYMED_ENHMF:
                using (var metafile = new Metafile(medium.unionmember, deleteEmf: false))
                {
                    SaveDecodedImage(metafile, result, cellDirectory, "enhmetafile");
                }
                break;
            default:
                throw new NotSupportedException(
                    $"Advertised medium {medium.tymed} has no complete reader.");
        }
    }

    private static byte[] ReadHGlobal(IntPtr handle)
    {
        var size = checked((long)NativeMethods.GlobalSize(handle).ToUInt64());
        if (size < 0 || size > MaximumPayloadBytes)
        {
            throw new InvalidDataException($"HGLOBAL size {size} is outside the safety limit.");
        }

        if (size == 0)
        {
            return Array.Empty<byte>();
        }

        var pointer = NativeMethods.GlobalLock(handle);
        if (pointer == IntPtr.Zero)
        {
            throw new InvalidOperationException(
                $"GlobalLock failed with Win32 error {Marshal.GetLastWin32Error()}.");
        }

        try
        {
            var bytes = new byte[checked((int)size)];
            Marshal.Copy(pointer, bytes, 0, bytes.Length);
            return bytes;
        }
        finally
        {
            NativeMethods.GlobalUnlock(handle);
        }
    }

    private static byte[] ReadComStream(IntPtr streamPointer)
    {
        if (streamPointer == IntPtr.Zero)
        {
            throw new InvalidDataException("TYMED_ISTREAM returned a null pointer.");
        }

        var instance = Marshal.GetObjectForIUnknown(streamPointer);
        if (instance is not IStream stream)
        {
            throw new InvalidCastException("TYMED_ISTREAM pointer is not an IStream.");
        }

        try
        {
            stream.Stat(out var statistics, 1);
            if (statistics.cbSize < 0 || statistics.cbSize > MaximumPayloadBytes)
            {
                throw new InvalidDataException(
                    $"IStream size {statistics.cbSize} is outside the safety limit.");
            }

            stream.Seek(0, 0, IntPtr.Zero);
            using var output = statistics.cbSize > 0
                ? new MemoryStream(checked((int)statistics.cbSize))
                : new MemoryStream();
            var buffer = new byte[64 * 1024];
            var readPointer = Marshal.AllocHGlobal(sizeof(int));
            try
            {
                while (true)
                {
                    Marshal.WriteInt32(readPointer, 0);
                    stream.Read(buffer, buffer.Length, readPointer);
                    var read = Marshal.ReadInt32(readPointer);
                    if (read == 0)
                    {
                        break;
                    }

                    if (read < 0 || read > buffer.Length
                        || output.Length + read > MaximumPayloadBytes)
                    {
                        throw new InvalidDataException("IStream returned an invalid byte count.");
                    }

                    output.Write(buffer, 0, read);
                }
            }
            finally
            {
                Marshal.FreeHGlobal(readPointer);
            }

            if (statistics.cbSize > 0 && output.Length != statistics.cbSize)
            {
                throw new EndOfStreamException(
                    $"IStream advertised {statistics.cbSize} bytes but returned {output.Length}.");
            }

            return output.ToArray();
        }
        finally
        {
            if (Marshal.IsComObject(stream))
            {
                Marshal.ReleaseComObject(stream);
            }
        }
    }

    private static void ReadTymedFile(
        IntPtr filePointer,
        FormatManifest result,
        string cellDirectory)
    {
        var filePath = Marshal.PtrToStringUni(filePointer);
        if (string.IsNullOrWhiteSpace(filePath))
        {
            throw new InvalidDataException("TYMED_FILE returned an empty path.");
        }

        result.ExtractedPaths.Add(filePath);
        CopyReferencedFile(filePath, result, cellDirectory, 0);
        var pathBytes = Encoding.Unicode.GetBytes(filePath + "\0");
        SaveRaw(pathBytes, result, cellDirectory, "tymed_file_path");
    }

    private static void ReadBinaryPayload(
        byte[] bytes,
        FormatManifest result,
        string cellDirectory,
        string source)
    {
        SaveRaw(bytes, result, cellDirectory, source);

        switch (result.Classification)
        {
            case "file-list":
                var paths = result.FormatId == 15
                    ? ParseFileDrop(bytes)
                    : ParsePathText(bytes);
                AddReferencedPaths(paths, result, cellDirectory);
                break;
            case "uri-list":
                AddReferencedPaths(ParseUriList(bytes), result, cellDirectory);
                break;
            case "text":
                result.Text = DecodeText(bytes, result.FormatId == 13);
                break;
            case "image":
                DecodeImagePayload(bytes, result, cellDirectory, source);
                break;
        }
    }

    private static void SaveRaw(
        byte[] bytes,
        FormatManifest result,
        string cellDirectory,
        string source)
    {
        var path = Path.Combine(
            cellDirectory,
            "formats",
            $"{result.Index:D3}_{SafeName(result.FormatName)}_{source}.bin");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllBytes(path, bytes);
        result.DumpFiles.Add(Artifact.FromFile(cellDirectory, path, "raw"));
    }

    private static void AddReferencedPaths(
        IEnumerable<string> paths,
        FormatManifest result,
        string cellDirectory)
    {
        foreach (var path in paths.Where(path => !string.IsNullOrWhiteSpace(path)).Distinct())
        {
            result.ExtractedPaths.Add(path);
            CopyReferencedFile(path, result, cellDirectory, result.ReferencedFiles.Count);
        }
    }

    private static void CopyReferencedFile(
        string path,
        FormatManifest result,
        string cellDirectory,
        int index)
    {
        var fullPath = Path.GetFullPath(path);
        if (!File.Exists(fullPath))
        {
            throw new FileNotFoundException("OLE referenced file does not exist.", fullPath);
        }

        var target = Path.Combine(
            cellDirectory,
            "referenced_files",
            $"{result.Index:D3}_{index:D2}_{SafeName(Path.GetFileName(fullPath))}");
        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        File.Copy(fullPath, target, overwrite: false);
        result.ReferencedFiles.Add(new ReferencedFileArtifact
        {
            OriginalPath = fullPath,
            Copy = Artifact.FromFile(cellDirectory, target, "referenced-file"),
        });
    }

    private static List<string> ParseFileDrop(byte[] bytes)
    {
        if (bytes.Length < 20)
        {
            throw new InvalidDataException("CF_HDROP payload is shorter than DROPFILES.");
        }

        var offset = BitConverter.ToInt32(bytes, 0);
        var wide = BitConverter.ToInt32(bytes, 16) != 0;
        if (offset < 20 || offset > bytes.Length)
        {
            throw new InvalidDataException("CF_HDROP has an invalid pFiles offset.");
        }

        var text = wide
            ? Encoding.Unicode.GetString(bytes, offset, bytes.Length - offset)
            : Encoding.Default.GetString(bytes, offset, bytes.Length - offset);
        return text.Split(new[] { '\0' }, StringSplitOptions.RemoveEmptyEntries).ToList();
    }

    private static List<string> ParsePathText(byte[] bytes)
    {
        var text = DecodeText(bytes, preferUnicode: true);
        return text.Split(new[] { '\0', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(value => value.Trim())
            .Where(value => value.Length > 0)
            .ToList();
    }

    private static List<string> ParseUriList(byte[] bytes)
    {
        var paths = new List<string>();
        var text = DecodeText(bytes, preferUnicode: false);
        foreach (var line in text.Split(
            new[] { '\0', '\r', '\n' },
            StringSplitOptions.RemoveEmptyEntries))
        {
            var value = line.Trim();
            if (value.Length == 0 || value.StartsWith("#", StringComparison.Ordinal))
            {
                continue;
            }

            if (Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.IsFile)
            {
                paths.Add(uri.LocalPath);
            }
            else if (Path.IsPathRooted(value))
            {
                paths.Add(value);
            }
            else
            {
                throw new InvalidDataException($"Unclassified URI-list entry: {value}");
            }
        }

        return paths;
    }

    private static string DecodeText(byte[] bytes, bool preferUnicode)
    {
        if (bytes.Length == 0)
        {
            return string.Empty;
        }

        var oddNulls = 0;
        var oddCount = 0;
        for (var index = 1; index < bytes.Length; index += 2)
        {
            oddCount++;
            if (bytes[index] == 0)
            {
                oddNulls++;
            }
        }

        var unicode = preferUnicode || (oddCount > 0 && oddNulls * 2 > oddCount);
        return (unicode ? Encoding.Unicode : Encoding.UTF8)
            .GetString(bytes)
            .TrimEnd('\0');
    }

    private static void DecodeImagePayload(
        byte[] bytes,
        FormatManifest result,
        string cellDirectory,
        string source)
    {
        var errors = new List<string>();
        if (result.FormatId is 8 or 17
            || ContainsIgnoreCase(result.FormatName, "dib"))
        {
            if (Is32BitDib(bytes))
            {
                using var image = Decode32BitDib(bytes);
                SaveDecodedImage(image, result, cellDirectory, source + "_dib32");
                return;
            }

            try
            {
                using var image = Image.FromStream(new MemoryStream(WrapDibAsBmp(bytes)));
                SaveDecodedImage(image, result, cellDirectory, source + "_dib");
                return;
            }
            catch (Exception exception)
            {
                errors.Add("DIB: " + exception.Message);
            }
        }

        try
        {
            using var stream = new MemoryStream(bytes, writable: false);
            using var image = Image.FromStream(stream, useEmbeddedColorManagement: false, validateImageData: true);
            SaveDecodedImage(image, result, cellDirectory, source + "_encoded");
            return;
        }
        catch (Exception exception)
        {
            errors.Add("encoded: " + exception.Message);
        }

        if (ContainsIgnoreCase(result.FormatName, "DragImageBits"))
        {
            try
            {
                using var image = DecodeShellDragImage(bytes);
                SaveDecodedImage(image, result, cellDirectory, source + "_shell_drag");
                return;
            }
            catch (Exception exception)
            {
                errors.Add("SHDRAGIMAGE: " + exception.Message);
            }
        }

        throw new InvalidDataException(
            $"No image decoder accepted {result.FormatName}: {string.Join(" | ", errors)}");
    }

    private static byte[] WrapDibAsBmp(byte[] dib)
    {
        if (dib.Length < 12)
        {
            throw new InvalidDataException("DIB is too short for a bitmap header.");
        }

        var headerSize = BitConverter.ToInt32(dib, 0);
        if (headerSize < 12 || headerSize > dib.Length)
        {
            throw new InvalidDataException($"DIB header size {headerSize} is invalid.");
        }

        int bitCount;
        int paletteEntrySize;
        int paletteEntries;
        var extraMasks = 0;
        if (headerSize == 12)
        {
            bitCount = BitConverter.ToUInt16(dib, 10);
            paletteEntrySize = 3;
            paletteEntries = bitCount <= 8 ? 1 << bitCount : 0;
        }
        else
        {
            if (dib.Length < 40)
            {
                throw new InvalidDataException("BITMAPINFOHEADER is truncated.");
            }

            bitCount = BitConverter.ToUInt16(dib, 14);
            var compression = BitConverter.ToInt32(dib, 16);
            var colorsUsed = BitConverter.ToInt32(dib, 32);
            paletteEntrySize = 4;
            paletteEntries = colorsUsed > 0 ? colorsUsed : bitCount <= 8 ? 1 << bitCount : 0;
            if (headerSize == 40 && compression is 3 or 6)
            {
                extraMasks = compression == 6 ? 16 : 12;
            }
        }

        var pixelOffset = checked(headerSize + extraMasks + paletteEntries * paletteEntrySize);
        if (pixelOffset < headerSize || pixelOffset > dib.Length)
        {
            throw new InvalidDataException("DIB pixel offset is outside the payload.");
        }

        var bmp = new byte[checked(14 + dib.Length)];
        bmp[0] = (byte)'B';
        bmp[1] = (byte)'M';
        Buffer.BlockCopy(BitConverter.GetBytes(bmp.Length), 0, bmp, 2, 4);
        Buffer.BlockCopy(BitConverter.GetBytes(14 + pixelOffset), 0, bmp, 10, 4);
        Buffer.BlockCopy(dib, 0, bmp, 14, dib.Length);
        return bmp;
    }

    private static bool Is32BitDib(byte[] dib)
    {
        if (dib.Length < 16)
        {
            return false;
        }
        var headerSize = BitConverter.ToInt32(dib, 0);
        return headerSize >= 40
            && headerSize <= dib.Length
            && BitConverter.ToUInt16(dib, 14) == 32;
    }

    private static Bitmap Decode32BitDib(byte[] dib)
    {
        var headerSize = BitConverter.ToInt32(dib, 0);
        var width = BitConverter.ToInt32(dib, 4);
        var signedHeight = BitConverter.ToInt32(dib, 8);
        var planes = BitConverter.ToUInt16(dib, 12);
        var bitCount = BitConverter.ToUInt16(dib, 14);
        var compression = BitConverter.ToInt32(dib, 16);
        if (headerSize < 40 || headerSize > dib.Length
            || width <= 0 || signedHeight == 0
            || width > 16384 || Math.Abs((long)signedHeight) > 16384
            || planes != 1 || bitCount != 32
            || compression is not (0 or 3 or 6))
        {
            throw new InvalidDataException("Unsupported 32-bit DIB layout.");
        }

        ValidateStandard32BitMasks(dib, headerSize, compression);
        var height = Math.Abs(signedHeight);
        var pixelOffset = ComputeDibPixelOffset(dib, headerSize, bitCount, compression);
        var sourceStride = checked(width * 4);
        var requiredLength = checked(pixelOffset + sourceStride * height);
        if (requiredLength > dib.Length)
        {
            throw new InvalidDataException("32-bit DIB pixel data is truncated.");
        }

        var topDownBgra = new byte[checked(sourceStride * height)];
        for (var y = 0; y < height; y++)
        {
            var sourceY = signedHeight > 0 ? height - y - 1 : y;
            Buffer.BlockCopy(
                dib,
                checked(pixelOffset + sourceY * sourceStride),
                topDownBgra,
                y * sourceStride,
                sourceStride);
        }
        return CreateBitmapFromTopDownBgra(width, height, topDownBgra);
    }

    private static void ValidateStandard32BitMasks(
        byte[] dib,
        int headerSize,
        int compression)
    {
        if (compression == 0)
        {
            return;
        }

        const int maskOffset = 40;
        var maskCount = compression == 6 ? 4 : 3;
        if (maskOffset + maskCount * 4 > dib.Length)
        {
            throw new InvalidDataException("32-bit DIB channel masks are truncated.");
        }
        var red = BitConverter.ToUInt32(dib, maskOffset);
        var green = BitConverter.ToUInt32(dib, maskOffset + 4);
        var blue = BitConverter.ToUInt32(dib, maskOffset + 8);
        var alpha = maskCount == 4 ? BitConverter.ToUInt32(dib, maskOffset + 12) : 0u;
        if (red != 0x00FF0000u
            || green != 0x0000FF00u
            || blue != 0x000000FFu
            || (alpha != 0u && alpha != 0xFF000000u))
        {
            throw new InvalidDataException("32-bit DIB uses unsupported channel masks.");
        }
    }

    private static int ComputeDibPixelOffset(
        byte[] dib,
        int headerSize,
        int bitCount,
        int compression)
    {
        var colorsUsed = headerSize >= 36 ? BitConverter.ToInt32(dib, 32) : 0;
        var paletteEntries = colorsUsed > 0 ? colorsUsed : bitCount <= 8 ? 1 << bitCount : 0;
        var extraMasks = headerSize == 40 && compression is 3 or 6
            ? compression == 6 ? 16 : 12
            : 0;
        var pixelOffset = checked(headerSize + extraMasks + paletteEntries * 4);
        if (pixelOffset < headerSize || pixelOffset > dib.Length)
        {
            throw new InvalidDataException("DIB pixel offset is outside the payload.");
        }
        return pixelOffset;
    }

    private static Image DecodeShellDragImage(byte[] bytes)
    {
        var required = IntPtr.Size == 8 ? 32 : 24;
        if (bytes.Length < required)
        {
            throw new InvalidDataException("DragImageBits is shorter than SHDRAGIMAGE.");
        }

        var width = BitConverter.ToInt32(bytes, 0);
        var height = BitConverter.ToInt32(bytes, 4);
        if (width <= 0 || height <= 0 || width > 16384 || height > 16384)
        {
            throw new InvalidDataException($"SHDRAGIMAGE size {width}x{height} is invalid.");
        }

        var handleValue = IntPtr.Size == 8
            ? BitConverter.ToInt64(bytes, 16)
            : BitConverter.ToInt32(bytes, 16);
        var bitmapHandle = new IntPtr(handleValue);
        if (bitmapHandle == IntPtr.Zero)
        {
            throw new InvalidDataException("SHDRAGIMAGE does not contain a usable HBITMAP.");
        }

        return CaptureHBitmap(bitmapHandle, width, height);
    }

    private static Bitmap CaptureHBitmap(
        IntPtr bitmapHandle,
        int? expectedWidth = null,
        int? expectedHeight = null)
    {
        var nativeBitmap = new NativeBitmap();
        var nativeSize = Marshal.SizeOf(typeof(NativeBitmap));
        var copied = NativeMethods.GetObject(
            bitmapHandle,
            nativeSize,
            ref nativeBitmap);
        if (copied != nativeSize)
        {
            throw new InvalidDataException(
                $"GetObject copied {copied} bytes for HBITMAP; expected {nativeSize}.");
        }

        var width = nativeBitmap.Width;
        var signedHeight = (long)nativeBitmap.Height;
        if (width <= 0 || signedHeight == 0
            || width > 16384 || Math.Abs(signedHeight) > 16384
            || (expectedWidth is not null && width != expectedWidth.Value)
            || (expectedHeight is not null && Math.Abs(signedHeight) != expectedHeight.Value))
        {
            throw new InvalidDataException(
                $"HBITMAP size {width}x{signedHeight} does not match its contract.");
        }
        var height = checked((int)Math.Abs(signedHeight));

        var topDownBgra = new byte[checked(width * height * 4)];
        if (nativeBitmap.Bits != IntPtr.Zero
            && nativeBitmap.Planes == 1
            && nativeBitmap.BitsPixel == 32)
        {
            var sourceStride = Math.Abs(nativeBitmap.WidthBytes);
            if (sourceStride < width * 4)
            {
                throw new InvalidDataException("HBITMAP stride is shorter than one BGRA row.");
            }
            var sourceRow = new byte[sourceStride];
            for (var y = 0; y < height; y++)
            {
                var sourceY = signedHeight > 0 ? height - y - 1 : y;
                Marshal.Copy(
                    IntPtr.Add(nativeBitmap.Bits, checked(sourceY * sourceStride)),
                    sourceRow,
                    0,
                    sourceStride);
                Buffer.BlockCopy(sourceRow, 0, topDownBgra, y * width * 4, width * 4);
            }
        }
        else
        {
            ReadHBitmapWithGetDibits(bitmapHandle, width, height, topDownBgra);
        }

        return CreateBitmapFromTopDownBgra(width, height, topDownBgra);
    }

    private static void ReadHBitmapWithGetDibits(
        IntPtr bitmapHandle,
        int width,
        int height,
        byte[] topDownBgra)
    {
        var bitmapInfo = new NativeBitmapInfo
        {
            Header = new NativeBitmapInfoHeader
            {
                Size = (uint)Marshal.SizeOf(typeof(NativeBitmapInfoHeader)),
                Width = width,
                Height = -height,
                Planes = 1,
                BitCount = 32,
                Compression = 0,
                SizeImage = (uint)topDownBgra.Length,
            },
        };
        var deviceContext = NativeMethods.GetDC(IntPtr.Zero);
        if (deviceContext == IntPtr.Zero)
        {
            throw new InvalidOperationException("GetDC failed while reading HBITMAP.");
        }

        var pinned = GCHandle.Alloc(topDownBgra, GCHandleType.Pinned);
        try
        {
            var rows = NativeMethods.GetDIBits(
                deviceContext,
                bitmapHandle,
                0,
                (uint)height,
                pinned.AddrOfPinnedObject(),
                ref bitmapInfo,
                0);
            if (rows != height)
            {
                throw new InvalidDataException(
                    $"GetDIBits returned {rows} rows; expected {height}.");
            }
        }
        finally
        {
            pinned.Free();
            NativeMethods.ReleaseDC(IntPtr.Zero, deviceContext);
        }
    }

    private static Bitmap CreateBitmapFromTopDownBgra(
        int width,
        int height,
        byte[] topDownBgra)
    {
        var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        var data = bitmap.LockBits(
            new Rectangle(0, 0, width, height),
            ImageLockMode.WriteOnly,
            PixelFormat.Format32bppArgb);
        try
        {
            var rowBytes = checked(width * 4);
            for (var y = 0; y < height; y++)
            {
                var destinationY = data.Stride >= 0 ? y : height - y - 1;
                Marshal.Copy(
                    topDownBgra,
                    y * rowBytes,
                    IntPtr.Add(data.Scan0, destinationY * Math.Abs(data.Stride)),
                    rowBytes);
            }
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
        return bitmap;
    }

    private static void SaveDecodedImage(
        Image source,
        FormatManifest result,
        string cellDirectory,
        string sourceLabel)
    {
        if (source.Width <= 0 || source.Height <= 0
            || source.Width > 16384 || source.Height > 16384)
        {
            throw new InvalidDataException(
                $"Decoded image size {source.Width}x{source.Height} is invalid.");
        }

        using var bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            graphics.DrawImageUnscaled(source, 0, 0);
        }

        var baseName = $"{result.Index:D3}_{SafeName(result.FormatName)}_{sourceLabel}";
        var pngPath = Path.Combine(cellDirectory, "decoded_images", baseName + ".png");
        var rgbaPath = Path.Combine(cellDirectory, "decoded_images", baseName + ".rgba");
        Directory.CreateDirectory(Path.GetDirectoryName(pngPath)!);
        bitmap.Save(pngPath, ImageFormat.Png);

        var rgba = new byte[checked(bitmap.Width * bitmap.Height * 4)];
        var outputIndex = 0;
        for (var y = 0; y < bitmap.Height; y++)
        {
            for (var x = 0; x < bitmap.Width; x++)
            {
                var color = bitmap.GetPixel(x, y);
                rgba[outputIndex++] = color.R;
                rgba[outputIndex++] = color.G;
                rgba[outputIndex++] = color.B;
                rgba[outputIndex++] = color.A;
            }
        }
        File.WriteAllBytes(rgbaPath, rgba);

        result.DecodedImages.Add(new DecodedImageArtifact
        {
            Width = bitmap.Width,
            Height = bitmap.Height,
            Source = sourceLabel,
            Png = Artifact.FromFile(cellDirectory, pngPath, "decoded-png"),
            Rgba = Artifact.FromFile(cellDirectory, rgbaPath, "decoded-rgba"),
        });
    }

    private static string SafeName(string value)
    {
        var invalid = Path.GetInvalidFileNameChars().ToHashSet();
        var safe = new string(value.Select(character =>
            invalid.Contains(character) || char.IsControl(character) ? '_' : character).ToArray());
        return safe.Length <= 80 ? safe : safe.Substring(0, 80);
    }

    private static bool ContainsIgnoreCase(string value, string search)
    {
        return value.IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0;
    }
}

internal static class ManifestWriter
{
    private static readonly JavaScriptSerializer Serializer = new()
    {
        MaxJsonLength = int.MaxValue,
        RecursionLimit = 100,
    };

    public static void Write(string cellDirectory, DropManifest manifest)
    {
        Directory.CreateDirectory(cellDirectory);
        var path = Path.Combine(cellDirectory, "manifest.json");
        File.WriteAllText(
            path,
            Serializer.Serialize(manifest),
            new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
    }
}

internal sealed class DropManifest
{
    public int SchemaVersion { get; set; } = 1;
    public string CapturedAtUtc { get; set; } = DateTime.UtcNow.ToString("O");
    public string Mode { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public string Payload { get; set; } = string.Empty;
    public int ProcessBitness { get; set; }
    public bool InspectionPassed { get; set; }
    public string? FatalError { get; set; }
    public List<FormatManifest> Formats { get; } = [];
}

internal sealed class FormatManifest
{
    public int Index { get; set; }
    public int FormatId { get; set; }
    public string FormatName { get; set; } = string.Empty;
    public string AdvertisedTymed { get; set; } = string.Empty;
    public string ActualTymed { get; set; } = string.Empty;
    public string Aspect { get; set; } = string.Empty;
    public int Lindex { get; set; }
    public string Classification { get; set; } = "unknown";
    public bool IsImageCandidate { get; set; }
    public string Status { get; set; } = "pending";
    public string? Error { get; set; }
    public bool ReleaseStgMediumCalled { get; set; }
    public string? Text { get; set; }
    public List<string> ExtractedPaths { get; } = [];
    public List<Artifact> DumpFiles { get; } = [];
    public List<ReferencedFileArtifact> ReferencedFiles { get; } = [];
    public List<DecodedImageArtifact> DecodedImages { get; } = [];
}

internal sealed class Artifact
{
    public string Role { get; set; } = string.Empty;
    public string RelativePath { get; set; } = string.Empty;
    public long Length { get; set; }
    public string Sha256 { get; set; } = string.Empty;

    public static Artifact FromFile(string cellDirectory, string filePath, string role)
    {
        using var stream = File.OpenRead(filePath);
        return new Artifact
        {
            Role = role,
            RelativePath = MakeRelativePath(cellDirectory, filePath).Replace('\\', '/'),
            Length = stream.Length,
            Sha256 = ComputeSha256(stream),
        };
    }

    private static string MakeRelativePath(string directory, string filePath)
    {
        var baseUri = new Uri(Path.GetFullPath(directory).TrimEnd('\\') + "\\");
        var fileUri = new Uri(Path.GetFullPath(filePath));
        return Uri.UnescapeDataString(baseUri.MakeRelativeUri(fileUri).ToString());
    }

    private static string ComputeSha256(Stream stream)
    {
        using var sha256 = SHA256.Create();
        return BitConverter.ToString(sha256.ComputeHash(stream))
            .Replace("-", string.Empty)
            .ToLowerInvariant();
    }
}

internal sealed class ReferencedFileArtifact
{
    public string OriginalPath { get; set; } = string.Empty;
    public Artifact Copy { get; set; } = new();
}

internal sealed class DecodedImageArtifact
{
    public int Width { get; set; }
    public int Height { get; set; }
    public string Source { get; set; } = string.Empty;
    public Artifact Png { get; set; } = new();
    public Artifact Rgba { get; set; } = new();
}

internal static class NativeMethods
{
    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern UIntPtr GlobalSize(IntPtr memory);

    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern IntPtr GlobalLock(IntPtr memory);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GlobalUnlock(IntPtr memory);

    [DllImport("ole32.dll")]
    internal static extern void ReleaseStgMedium(ref STGMEDIUM medium);

    [DllImport("gdi32.dll", EntryPoint = "GetObjectW", SetLastError = true)]
    internal static extern int GetObject(
        IntPtr handle,
        int bufferSize,
        ref NativeBitmap bitmap);

    [DllImport("gdi32.dll", SetLastError = true)]
    internal static extern int GetDIBits(
        IntPtr deviceContext,
        IntPtr bitmap,
        uint startScan,
        uint scanLines,
        IntPtr bits,
        ref NativeBitmapInfo bitmapInfo,
        uint usage);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern IntPtr GetDC(IntPtr window);

    [DllImport("user32.dll")]
    internal static extern int ReleaseDC(IntPtr window, IntPtr deviceContext);

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DeleteObject(IntPtr handle);
}

[StructLayout(LayoutKind.Sequential)]
internal struct NativeBitmap
{
    internal int Type;
    internal int Width;
    internal int Height;
    internal int WidthBytes;
    internal ushort Planes;
    internal ushort BitsPixel;
    internal IntPtr Bits;
}

[StructLayout(LayoutKind.Sequential)]
internal struct NativeBitmapInfoHeader
{
    internal uint Size;
    internal int Width;
    internal int Height;
    internal ushort Planes;
    internal ushort BitCount;
    internal uint Compression;
    internal uint SizeImage;
    internal int XPelsPerMeter;
    internal int YPelsPerMeter;
    internal uint ColorsUsed;
    internal uint ColorsImportant;
}

[StructLayout(LayoutKind.Sequential)]
internal struct NativeBitmapInfo
{
    internal NativeBitmapInfoHeader Header;
    internal uint Colors;
}
