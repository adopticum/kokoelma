// scripts/seed-prod-users.js
// Do not call this directly, run "seed-users.sh" shell script instead.

import { createClient } from '@supabase/supabase-js'

const emails = [
    'gb@adopticum.net',
    'tonin81418@googxs.com',
    'tojafit549@brixozu.com',
]

const { SUPABASE_URL, SUPABASE_SECRET_KEY } = process.env

if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) {
    console.error("Error: SUPABASE_URL and SUPABASE_SECRET_KEY needs to be defined in the environment. Source supabase-env file.")
    process.exit(1)
}

if (!/^sb_secret_[A-Za-z0-9_-]+$/.test(SUPABASE_SECRET_KEY)) {
    console.error("Error: SUPABASE_SECRET_KEY is not the expected format.")
    process.exit(2)
}

const supabase = createClient(
    SUPABASE_URL,
    SUPABASE_SECRET_KEY
)

for (const email of emails) {
    const { data, error } = await supabase.auth.admin.createUser({
        email,
        email_confirm: true,
        //password: '',  // password is optional and not relevant in this context.
        //user_metadata: { role: 'admin' }  // omit. not relevant.
    })

    if (error) {
        if (error.status === 422 && error.code === 'email_exists') {
            console.log(`${email} already exists, skipping.`)
            continue
        }
        console.error(`Failed to create ${email}:`, error)
        throw error
    }

    console.log(`${email} created`, data)
}
