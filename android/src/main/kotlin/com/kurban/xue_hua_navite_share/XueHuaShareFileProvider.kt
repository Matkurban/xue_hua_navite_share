package com.kurban.xue_hua_navite_share

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException

/**
 * Self-contained [ContentProvider] that securely exposes local and cached files
 * as `content://` URIs with read permissions (`FLAG_GRANT_READ_URI_PERMISSION`)
 * without requiring external AndroidX dependencies.
 */
class XueHuaShareFileProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val file = resolveFileForUri(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cols = ArrayList<String>(columns.size)
        val values = ArrayList<Any?>(columns.size)

        for (col in columns) {
            when (col) {
                OpenableColumns.DISPLAY_NAME -> {
                    cols.add(OpenableColumns.DISPLAY_NAME)
                    values.add(uri.getQueryParameter("displayName") ?: file.name)
                }
                OpenableColumns.SIZE -> {
                    cols.add(OpenableColumns.SIZE)
                    values.add(file.length())
                }
            }
        }

        val cursor = MatrixCursor(cols.toTypedArray(), 1)
        cursor.addRow(values.toArray())
        return cursor
    }

    override fun getType(uri: Uri): String {
        val explicitMime = uri.getQueryParameter("mimeType")
        if (!explicitMime.isNullOrBlank()) {
            return explicitMime
        }
        val file = resolveFileForUri(uri)
        val extension = file.extension.lowercase()
        if (extension.isNotEmpty()) {
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            if (!mime.isNullOrBlank()) {
                return mime
            }
        }
        return "application/octet-stream"
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val file = resolveFileForUri(uri)
        if (!file.exists()) {
            throw FileNotFoundException("Shared file does not exist: ${file.absolutePath}")
        }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? {
        throw UnsupportedOperationException("XueHuaShareFileProvider is read-only.")
    }

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
        throw UnsupportedOperationException("XueHuaShareFileProvider is read-only.")
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int {
        throw UnsupportedOperationException("XueHuaShareFileProvider is read-only.")
    }

    private fun resolveFileForUri(uri: Uri): File {
        val encodedPath = uri.getQueryParameter("path")
            ?: uri.path
            ?: throw FileNotFoundException("Missing file path in URI: $uri")
        return File(encodedPath).canonicalFile
    }

    companion object {
        /**
         * Builds a `content://` [Uri] for the given [file] scoped to the host app's authority.
         */
        fun getUriForFile(
            context: Context,
            file: File,
            displayName: String? = null,
            mimeType: String? = null
        ): Uri {
            val authority = "${context.packageName}.xue_hua_navite_share.fileprovider"
            val builder = Uri.Builder()
                .scheme("content")
                .authority(authority)
                .appendPath("share")
                .appendPath(displayName ?: file.name)
                .appendQueryParameter("path", file.canonicalPath)

            if (!displayName.isNullOrBlank()) {
                builder.appendQueryParameter("displayName", displayName)
            }
            if (!mimeType.isNullOrBlank()) {
                builder.appendQueryParameter("mimeType", mimeType)
            }
            return builder.build()
        }
    }
}
