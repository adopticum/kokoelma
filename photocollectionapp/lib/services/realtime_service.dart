/* 
A service dedicated to handle updates pushed from the backend (i.e. Supabase Realtime).
This can include notifications, profile updates, group membership changes, etc.
The service listens to changes in the database and updates the local state accordingly.
This service is part on the user-scoped provider subtree, created at login/reconnection and destroyed at logout.
By using this service we can avoid auth state dependent code in the viewmodels, and instead have a single source of truth for realtime updates.
*/

//TODO: Implement realtime service.