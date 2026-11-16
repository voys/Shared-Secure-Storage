package org.openvoipalliance.shared_secure_storage_example

import android.app.Application
import android.util.Log
import org.openvoipalliance.sharedsecurestorage.SharedSecureStorage

class ExampleApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // No Flutter engine exists yet, this is what e.g. a push message handler would do.
        valueReadBeforeFlutter = SharedSecureStorage.getInstance(this).read(KEY)
        Log.i("SharedSecureStorage", "Read before Flutter started: $valueReadBeforeFlutter")
    }

    companion object {
        const val KEY = "example.secret"

        var valueReadBeforeFlutter: String? = null
    }
}
